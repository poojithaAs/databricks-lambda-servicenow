terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# 1️⃣ Store Databricks Token Securely
resource "aws_secretsmanager_secret" "databricks_token" {
  name        = "/databricks/token"
  description = "Secure Databricks token"
}

resource "aws_secretsmanager_secret_version" "databricks_token_version" {
  secret_id     = aws_secretsmanager_secret.databricks_token.id
  secret_string = jsonencode({ DATABRICKS_TOKEN = var.databricks_token })
}

# 2️⃣ IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "lambda-databricks-secure-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

# 3️⃣ Permissions: Logs + Secrets Access
resource "aws_iam_role_policy_attachment" "lambda_logging" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "secret_access" {
  name = "lambda-databricks-secret-access"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["secretsmanager:GetSecretValue"],
      Resource = aws_secretsmanager_secret.databricks_token.arn
    }]
  })
}

resource "aws_iam_role_policy_attachment" "attach_secret_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.secret_access.arn
}

# 4️⃣ Zip the Lambda Folder
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda"
  output_path = "${path.module}/../lambda.zip"
}

# 5️⃣ Create the Lambda Function
resource "aws_lambda_function" "databricks_trigger" {
  function_name = "secure-databricks-trigger"
  runtime       = "python3.9"
  role          = aws_iam_role.lambda_role.arn
  handler       = "main.lambda_handler"
  filename      = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      DATABRICKS_HOST        = var.databricks_host
      JOB_ID                 = var.job_id
      DATABRICKS_SECRET_NAME = aws_secretsmanager_secret.databricks_token.name
      AWS_REGION             = var.region
    }
  }

  timeout = 60
}

# 6️⃣ Create API Gateway Endpoint
resource "aws_apigatewayv2_api" "databricks_api" {
  name          = "databricks-trigger-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id             = aws_apigatewayv2_api.databricks_api.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.databricks_trigger.invoke_arn
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "lambda_route" {
  api_id    = aws_apigatewayv2_api.databricks_api.id
  route_key = "POST /trigger"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_stage" "lambda_stage" {
  api_id      = aws_apigatewayv2_api.databricks_api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "apigw_permission" {
  statement_id  = "AllowAPIInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.databricks_trigger.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.databricks_api.execution_arn}/*/*"
}

output "api_endpoint" {
  value = aws_apigatewayv2_api.databricks_api.api_endpoint
}
