###############################################################
# Provider
###############################################################
provider "aws" {
  region = var.aws_region
}

###############################################################
# Detect if role exists
###############################################################
data "aws_iam_roles" "all" {}

locals {
  existing_lambda_role = contains(data.aws_iam_roles.all.names, "databricks_lambda_role")
}

###############################################################
# Create IAM role only if it doesn't exist
###############################################################
resource "aws_iam_role" "lambda_role" {
  count = local.existing_lambda_role ? 0 : 1

  name = "databricks_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = "sts:AssumeRole",
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

data "aws_caller_identity" "current" {}

# unified references
locals {
  lambda_role_name = local.existing_lambda_role
    ? "databricks_lambda_role"
    : aws_iam_role.lambda_role[0].name

  lambda_role_arn = local.existing_lambda_role
    ? "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/databricks_lambda_role"
    : aws_iam_role.lambda_role[0].arn
}

###############################################################
# CloudWatch logging policy
###############################################################
resource "aws_iam_role_policy" "lambda_logs" {
  name = "lambda_logging"
  role = local.lambda_role_name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      Resource = "arn:aws:logs:*:*:*"
    }]
  })
}

###############################################################
# Lambda function
###############################################################
resource "aws_lambda_function" "databricks_lambda" {
  function_name = "databricks_lambda_function"
  handler       = "main.lambda_handler"
  runtime       = "python3.12"
  role          = local.lambda_role_arn
  filename      = "../lambda.zip"
  timeout       = 15

  environment {
    variables = {
      DATABRICKS_HOST      = var.databricks_host
      DATABRICKS_HTTP_PATH = var.databricks_http_path
      DATABRICKS_TOKEN     = var.databricks_token
    }
  }
}

###############################################################
# API Gateway HTTP API
###############################################################
resource "aws_apigatewayv2_api" "lambda_api" {
  name          = "databricks_lambda_api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.lambda_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.databricks_lambda.invoke_arn
}

resource "aws_apigatewayv2_route" "lambda_route" {
  api_id    = aws_apigatewayv2_api.lambda_api.id
  route_key = "POST /query"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_stage" "lambda_stage" {
  api_id      = aws_apigatewayv2_api.lambda_api.id
  name        = var.env
  auto_deploy = true
}

###############################################################
# Output
###############################################################
output "invoke_url" {
  value = "${aws_apigatewayv2_stage.lambda_stage.invoke_url}/query"
}
