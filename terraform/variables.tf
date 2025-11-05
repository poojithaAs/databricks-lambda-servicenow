variable "aws_region" {}
variable "project_name" {}
variable "subnet_ids" {
  type = list(string)
}
variable "security_group_ids" {
  type = list(string)
}
variable "databricks_url" {}
variable "databricks_token" {}
variable "databricks_job_id" {}
