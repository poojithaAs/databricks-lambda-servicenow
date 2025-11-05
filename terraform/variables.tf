variable "region" {
  default = "us-east-1"
}

variable "databricks_host" {
  description = "Databricks workspace base URL"
}

variable "job_id" {
  description = "Databricks Job ID"
}

variable "databricks_token" {
  description = "Databricks PAT token"
  sensitive   = true
}
