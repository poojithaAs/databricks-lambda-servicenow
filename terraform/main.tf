terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = var.aws_region
}

# ------------------------------------------------------
# 1️⃣ AWS Secrets Manager — store Databricks credentials
# ------------------------------------------------------
resource "aws_secretsmanager_secret" "databricks_secret" {
  name        = "${var.project_name}-databricks-secret"
  description = "Databricks credentials for Lambda integration"
}

resource "aws_secretsmanager_secret_version" "databricks_secret_value" {
  secret_id = aws_secretsmanager_secret.databricks_secret.id

  secret_string = jsonencode({
    DATABRICKS_URL   = var.databricks_url
    DATABRICKS_TOKEN = var.databricks_token
    DATABRICKS_JOB_ID = var.databricks_job_id
  })
}

# ------------------------------------------------------
# 2️⃣ IAM Role and Policies for Lambda
# ------------------------------------------------------
resource "aws_iam_role" "lambda_role" {
  name_prefix = "${var.project_name}-lambda-role-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "lambda_policy" {
  name_prefix = "${var.project_name}-lambda-policy-"
  description = "Permissions for Lambda to access Secrets Manager, VPC, CloudWatch"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:*",
          "secretsmanager:GetSecretValue",
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# ------------------------------------------------------
# 3️⃣ Lambda Function — inside your existing VPC
# ------------------------------------------------------
resource "aws_lambda_function" "databricks_lambda" {
  function_name = "${var.project_name}-lambda"
  handler       = "main.lambda_handler"
  runtime       = "python3.9"
  role          = aws_iam_role.lambda_role.arn
  timeout       = 60

  filename         = "${path.module}/../lambda/lambda_package.zip"
  source_code_hash = filebase64sha256("${path.module}/../lambda/lambda_package.zip")

  environment {
    variables = {
      DATABRICKS_SECRET_NAME = aws_secretsmanager_secret.databricks_secret.name
    }
  }

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
  }
}

# ------------------------------------------------------
# 4️⃣ API Gateway → Lambda Integration
# ------------------------------------------------------
resource "aws_apigatewayv2_api" "lambda_api" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id                 = aws_apigatewayv2_api.lambda_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.databricks_lambda.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "lambda_route" {
  api_id    = aws_apigatewayv2_api.lambda_api.id
  route_key = "POST /trigger"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_lambda_permission" "allow_apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.databricks_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.lambda_api.execution_arn}/*/*"
}

# ------------------------------------------------------
# 5️⃣ Output API Gateway URL
# ------------------------------------------------------
output "api_gateway_url" {
  value = aws_apigatewayv2_api.lambda_api.api_endpoint
}
