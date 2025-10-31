provider "aws" { region = var.aws_region }

resource "aws_iam_role" "lambda_role" {
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

resource "aws_iam_role_policy" "lambda_logs" {
  name   = "lambda_logging"
  role   = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"],
      Resource = "arn:aws:logs:*:*:*"
    }]
  })
}

resource "aws_lambda_function" "databricks_lambda" {
  function_name = "databricks_lambda_function"
  handler       = "main.lambda_handler"
  runtime       = "python3.12"
  role          = aws_iam_role.lambda_role.arn
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

output "invoke_url" {
  value = "${aws_apigatewayv2_stage.lambda_stage.invoke_url}/query"
}

