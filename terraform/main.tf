terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = var.aws_region
}

resource "aws_iam_role" "lambda_role" {
  name_prefix = "${var.project_name}-lambda-role-"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_policy" "lambda_policy" {
  name_prefix = "${var.project_name}-lambda-policy-"
  description = "Lambda permissions for Databricks + CloudWatch"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = ["logs:*", "secretsmanager:GetSecretValue", "ssm:GetParameter"],
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

resource "aws_lambda_function" "databricks_lambda" {
  function_name = "${var.project_name}-lambda"
  handler       = "main.lambda_handler"
  runtime       = "python3.9"
  role          = aws_iam_role.lambda_role.arn
  filename         = "${path.module}/../lambda/lambda_package.zip"
  source_code_hash = filebase64sha256("${path.module}/../lambda/lambda_package.zip")
  environment {
    variables = {
      DATABRICKS_URL   = var.databricks_url
      DATABRICKS_TOKEN = var.databricks_token
      JOB_ID           = var.databricks_job_id
    }
  }
}

resource "aws_apigatewayv2_api" "lambda_api" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "integration" {
  api_id                 = aws_apigatewayv2_api.lambda_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.databricks_lambda.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "route" {
  api_id    = aws_apigatewayv2_api.lambda_api.id
  route_key = "POST /trigger"
  target    = "integrations/${aws_apigatewayv2_integration.integration.id}"
}

resource "aws_lambda_permission" "allow_apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.databricks_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.lambda_api.execution_arn}/*/*"
}

output "api_gateway_url" {
  value = aws_apigatewayv2_api.lambda_api.api_endpoint
}
