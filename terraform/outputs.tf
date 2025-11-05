output "lambda_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.databricks_lambda.function_name
}

output "api_gateway_url" {
  description = "Invoke URL for ServiceNow"
  value       = aws_apigatewayv2_api.lambda_api.api_endpoint
}
