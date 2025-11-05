variable "region" {
  description = "AWS Region"
  default     = "us-east-1"
}

variable "databricks_host" {
  description = "Databricks workspace base URL"
}

variable "job_id" {
  description = "Databricks job ID"
}

variable "databricks_token_secret_arn" {
  description = "ARN of the secret in AWS Secrets Manager containing Databricks token"
}
