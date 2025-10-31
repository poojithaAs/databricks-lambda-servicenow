output "lambda_endpoint" {
  value = aws_apigatewayv2_stage.lambda_stage.invoke_url
}
