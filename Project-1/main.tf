terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region  = "us-west-2"
  access_key = "YYYYYYYYY"
  secret_key = "XXXXXXXXXXXXXXXX"
}

#resource "aws_instance" "app_server" {
#  ami           = "ami-03f8756d29f0b5f21"
#  instance_type = "t2.micro"

#  tags = {
#    Name = "UbuntuServerApp"
#  }
#}

resource "aws_vpc" "prod-vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "Prod-vpc"
  }
}


# create GW

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.prod-vpc.id
}

# Create RT

resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  } 

  tags = {
    "Name" = "RT"
  }
}

# Create Subnet
resource "aws_subnet" "subnet-1" {
  vpc_id     = aws_vpc.prod-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-west-2a"

  tags = {
    Name = "prod-app-subnet"
  }
}

# Assosiate Subnet with RT

resource "aws_route_table_association" "rt-a" {
    subnet_id = aws_subnet.subnet-1.id
    route_table_id = aws_route_table.prod-route-table.id
}

# Create security group fo 22, 80, 443 ports
resource "aws_security_group" "allow_webssh" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.prod-vpc.id

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
 }

   ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
 }

   ingress {
    description      = "HTTPS"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
 }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web_ssh"
  }
}

# Create a network interface with an ip int he subnet that was created

resource "aws_network_interface" "web-server-nic" {
    subnet_id = aws_subnet.subnet-1.id
    private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_webssh.id]

}

# Create elastic IP

resource "aws_eip" "publicip" {
    vpc = true
    network_interface = aws_network_interface.web-server-nic.id
    associate_with_private_ip = "10.0.1.50"
    depends_on = [aws_internet_gateway.gw]
}

output "our_public_ip" {
  value = aws_eip.publicip.public_ip
}

# Create Server

resource "aws_instance" "web_app_server" {
  ami           = "ami-03f8756d29f0b5f21"
  instance_type = "t2.micro"
  availability_zone = "us-west-2a"
  key_name = "main-key"
  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.web-server-nic.id
  } 

  user_data = <<-EOF
            #!/bin/bash
            sudo apt update -y
            sudo apt install apache2 -y
            sudo systemctl start apache2
            sudo bash -c 'echo Your first web server > /var/www/html/index.html'
            EOF

    tags = {
    Name = "UbuntuServerApp"
 }
  
  }


