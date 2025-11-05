variable "aws_region" {
  description = "AWS region for deployment"
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix for all resource names"
  default     = "servicenow-databricks"
}

variable "databricks_secret_name" {
  description = "Name of existing AWS Secrets Manager secret"
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs for Lambda"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security groups for Lambda"
  type        = list(string)
}
