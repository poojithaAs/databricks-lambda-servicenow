variable "aws_region" { default = "us-east-1" }
variable "project_name" { default = "servicenow-databricks" }

# Databricks values (used to seed Secrets Manager only)
variable "databricks_url" {}
variable "databricks_token" { sensitive = true }
variable "databricks_job_id" {}

# Existing VPC details
variable "vpc_id" {
  description = "Existing VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security groups for Lambda"
  type        = list(string)
}
