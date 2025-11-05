output "lambda_name" {
  value = aws_lambda_function.databricks_trigger.function_name
}

output "api_url" {
  value = aws_apigatewayv2_api.databricks_api.api_endpoint
}
