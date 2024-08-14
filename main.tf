variable "region" {
  default = "us-east-1"
}

provider "aws" {
  region = var.region
}

resource "aws_iam_role" "stopinator_role" {
  name               = "stopinator-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "stopinator_lambda_basic_policy_attachment" {
  role = aws_iam_role.stopinator_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "stopinator_ec2_inline_policy" {
  name   = "stopinator-ec2-inline-policy"
  role   = aws_iam_role.stopinator_role.name
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeInstances",
        "ec2:StopInstances",
        "ec2:CreateTags"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

data "archive_file" "stopinator_zip" {
  type        = "zip"
  source_file = "stopinator.py"
  output_path = "stopinator.zip"
}

resource "aws_lambda_function" "stopinator_function" {
  filename         = "stopinator.zip"
  function_name    = "stopinator"
  role             = "${aws_iam_role.stopinator_role.arn}"
  handler          = "stopinator.lambda_handler"
  source_code_hash = "${data.archive_file.stopinator_zip.output_base64sha256}"
  runtime          = "python3.9"
  timeout          = 900
}

resource "aws_cloudwatch_event_rule" "stopinator_rule" {
  name                = "stopinator-rule"
  description         = "Triggers Stopinator at 6 AM (UTC) daily"
  schedule_expression = "cron(0 6 * * ? *)"
}

resource "aws_cloudwatch_event_target" "invoke_stopinator" {
  rule      = aws_cloudwatch_event_rule.stopinator_rule.name
  target_id = "invoke_stopinator"
  arn       = aws_lambda_function.stopinator_function.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.stopinator_function.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.stopinator_rule.arn
}

output "stopinator-function" {
  value = aws_lambda_function.stopinator_function.function_name
}
