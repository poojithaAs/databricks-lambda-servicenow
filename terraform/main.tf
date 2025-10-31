# Try to find existing role first
data "aws_iam_role" "existing_lambda_role" {
  name = "databricks_lambda_role"
}

# Create the role only if it doesn't exist
resource "aws_iam_role" "lambda_role" {
  count = length(data.aws_iam_role.existing_lambda_role.*.id) == 0 ? 1 : 0

  name = "databricks_lambda_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Unified reference for later use
locals {
  lambda_role_arn = length(data.aws_iam_role.existing_lambda_role.*.arn) > 0 ?
                    data.aws_iam_role.existing_lambda_role.arn :
                    aws_iam_role.lambda_role[0].arn
  lambda_role_id = length(data.aws_iam_role.existing_lambda_role.*.id) > 0 ?
                    data.aws_iam_role.existing_lambda_role.id :
                    aws_iam_role.lambda_role[0].id
}

# Attach CloudWatch logging policy
resource "aws_iam_role_policy" "lambda_logs" {
  name = "lambda_logging"
  role = local.lambda_role_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}
