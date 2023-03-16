resource "aws_cloudwatch_event_rule" "schedule" {
    name = "schedule-every-10-min"
    description = "Schedule for Lambda Function"
    schedule_expression = "cron(0/10 * ? * MON-FRI *)"
}

resource "aws_cloudwatch_event_target" "schedule_lambda" {
    rule = aws_cloudwatch_event_rule.schedule.name
    target_id = "processing_lambda"
    arn = aws_lambda_function.terraform_lambda_func.arn
}


resource "aws_lambda_permission" "allow_events_bridge_to_run_lambda" {
    statement_id = "AllowExecutionFromCloudWatch"
    action = "lambda:InvokeFunction"
    function_name = aws_lambda_function.terraform_lambda_func.function_name
    principal = "events.amazonaws.com"
    source_arn = aws_cloudwatch_event_rule.schedule.arn
}

