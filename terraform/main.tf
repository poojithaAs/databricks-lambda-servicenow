provider "aws" {
  region = var.region
}

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

resource "aws_iam_role_policy_attachment" "basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "secrets_access" {
  name        = "lambda-databricks-secrets-policy"
  description = "Allow Lambda to retrieve Databricks token from Secrets Manager"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"],
        Resource = var.databricks_token_secret_arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_secret_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.secrets_access.arn
}

resource "aws_lambda_function" "databricks_trigger" {
  function_name = "secure-databricks-trigger"
  runtime       = "python3.9"
  role          = aws_iam_role.lambda_role.arn
  handler       = "main.lambda_handler"
  filename      = "${path.module}/../lambda/lambda.zip"
  source_code_hash = filebase64sha256("${path.module}/../lambda/lambda.zip")

  environment {
    variables = {
      DATABRICKS_HOST              = var.databricks_host
      JOB_ID                       = var.job_id
      DATABRICKS_TOKEN_SECRET_ARN  = var.databricks_token_secret_arn
      AWS_REGION                   = var.region
    }
  }

  timeout = 60
}
