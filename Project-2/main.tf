resource "aws_vpc" "prod_vpc" {
  cidr_block           = "10.123.0.0/16"
  enable_dns_hostnames = true

  tags = {
    "Name" = "product_vpc"
  }
}

resource "aws_subnet" "prod_app_subnet" {

  vpc_id            = aws_vpc.prod_vpc.id
  cidr_block        = "10.123.1.0/24"
  availability_zone = "us-west-2a"
  tags = {
    "Name" = "Prod_app_subnet"
  }
}

resource "aws_internet_gateway" "prod-inet-gw" {
  vpc_id = aws_vpc.prod_vpc.id

  tags = {
    "Name" = "Prod-inet-GW"
  }

}

resource "aws_route_table" "prod_RT" {
  vpc_id = aws_vpc.prod_vpc.id

  tags = {
    "Name" = "Prod-Route-table"
  }
}

resource "aws_route" "prod_def_route" {
  route_table_id         = aws_route_table.prod_RT.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.prod-inet-gw.id

}

resource "aws_route_table_association" "prod_rt_assoc" {
  subnet_id      = aws_subnet.prod_app_subnet.id
  route_table_id = aws_route_table.prod_RT.id
}

resource "aws_security_group" "prod_sg" {
  name        = "prod_SecGroup"
  description = "Production security group for 22,80,443"
  vpc_id      = aws_vpc.prod_vpc.id

  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.prod_vpc.cidr_block]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["194.28.102.33/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]

  }


}

resource "aws_key_pair" "prod_auth" {
  key_name = "my-key"
  #public_key = file("~\\Documents\\terraform-projects\\main-key.pem")
  public_key = file("C:\\Users\\Viktor\\Dropbox\\dim\\mi\\id_rsa.pub")
}

resource "aws_instance" "prod_node" {
  instance_type          = "t2.micro"
  availability_zone      = "us-west-2a"
  key_name               = aws_key_pair.prod_auth.key_name
  ami                    = data.aws_ami.ami_data.id
  #vpc_security_group_ids = [aws_security_group.prod_sg.id]
  #subnet_id              = aws_subnet.prod_app_subnet.id

  user_data = file("userdata.tpl")

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.web-server-nic.id
  }

  tags = {
    "Name" = "Prod-web-server"
  }
}

resource "aws_eip" "publicip" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.123.1.10"
  depends_on                = [aws_internet_gateway.prod-inet-gw]
  
}

resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.prod_app_subnet.id
  private_ips     = ["10.123.1.10"]
  security_groups = [aws_security_group.prod_sg.id]

}

output "our_public_ip" {
  value = aws_eip.publicip.public_ip
}