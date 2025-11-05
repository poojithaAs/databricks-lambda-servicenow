terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.5.0"
}

provider "aws" {
  region = var.aws_region
}

# -----------------------------------------------------------------------------
# 🔹 IAM ROLE for Lambda (Create only if not already existing)
# -----------------------------------------------------------------------------
data "aws_iam_role" "existing_lambda_role" {
  name = "${var.project_name}-lambda-role"
  # Terraform will skip this lookup if role doesn’t exist yet
  # (ignore_errors is deprecated, so we use try() for safety in count logic)
}

resource "aws_iam_role" "lambda_role" {
  count = try(data.aws_iam_role.existing_lambda_role.name, "") != "" ? 0 : 1

  name = "${var.project_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# Choose the correct ARN whether it existed or was created
locals {
  lambda_role_arn = try(
    data.aws_iam_role.existing_lambda_role.arn,
    aws_iam_role.lambda_role[0].arn
  )
  lambda_role_name = try(
    data.aws_iam_role.existing_lambda_role.name,
    aws_iam_role.lambda_role[0].name
  )
}

# -----------------------------------------------------------------------------
# 🔹 IAM POLICY for Lambda (Create only if not already existing)
# -----------------------------------------------------------------------------
data "aws_iam_policy" "existing_lambda_policy" {
  name = "${var.project_name}-lambda-policy"
}

resource "aws_iam_policy" "lambda_policy" {
  count = try(data.aws_iam_policy.existing_lambda_policy.name, "") != "" ? 0 : 1

  name        = "${var.project_name}-lambda-policy"
  description = "Permissions for Lambda to access Secrets Manager and CloudWatch"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:*",
          "secretsmanager:GetSecretValue",
          "ssm:GetParameter"
        ],
        Resource = "*"
      }
    ]
  })
}

# Choose the correct ARN whether it existed or was created
locals {
  lambda_policy_arn = try(
    data.aws_iam_policy.existing_lambda_policy.arn,
    aws_iam_policy.lambda_policy[0].arn
  )
}

# -----------------------------------------------------------------------------
# 🔹 IAM Policy Attachment
# -----------------------------------------------------------------------------
resource "aws_iam_role_policy_attachment" "lambda_policy_attach" {
  role       = local.lambda_role_name
  policy_arn = local.lambda_policy_arn
}

# -----------------------------------------------------------------------------
# 🔹 Lambda Function
# -----------------------------------------------------------------------------
resource "aws_lambda_function" "databricks_lambda" {
  function_name = "${var.project_name}-lambda"
  handler       = "main.lambda_handler"
  runtime       = "python3.9"
  role          = local.lambda_role_arn
  timeout       = 60

  filename         = "${path.module}/../lambda/lambda_package.zip"
  source_code_hash = filebase64sha256("${path.module}/../lambda/lambda_package.zip")

  environment {
    variables = {
      DATABRICKS_URL   = var.databricks_url
      DATABRICKS_TOKEN = var.databricks_token
      JOB_ID           = var.databricks_job_id
    }
  }

  # (Optional) Remove this if not using VPC:
  # vpc_config {
  #   subnet_ids         = var.subnet_ids
  #   security_group_ids = var.security_group_ids
  # }
}

# -----------------------------------------------------------------------------
# 🔹 API Gateway
# -----------------------------------------------------------------------------
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

resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.databricks_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.lambda_api.execution_arn}/*/*"
}

# -----------------------------------------------------------------------------
# 🔹 Outputs
# -----------------------------------------------------------------------------
output "api_gateway_url" {
  description = "Invoke URL for ServiceNow"
  value       = aws_apigatewayv2_api.lambda_api.api_endpoint
}
