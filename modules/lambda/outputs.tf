output "function_name" {
  value = aws_lambda_function.api.function_name
}

output "function_arn" {
  value = aws_lambda_function.api.arn
}

output "api_gateway_url" {
  value = aws_apigatewayv2_stage.main.invoke_url
}

output "api_gateway_id" {
  value = aws_apigatewayv2_api.main.id
}
