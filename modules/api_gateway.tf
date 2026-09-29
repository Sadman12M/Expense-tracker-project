resource "aws_apigatewayv2_api" "expense_tracker_api" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = [
      "http://localhost:3000",
      "https://${aws_cloudfront_distribution.frontend.domain_name}"
    ]
    allow_methods = ["GET", "POST", "DELETE", "OPTIONS"]
    allow_headers = ["Content-Type", "Authorization"]
  }
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.expense_tracker_api.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_burst_limit = 20
    throttling_rate_limit  = 10
  }
}

resource "aws_apigatewayv2_authorizer" "cognito_authorizer" {
  api_id           = aws_apigatewayv2_api.expense_tracker_api.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "${var.project_name}-cognito-authorizer"

  jwt_configuration {
    audience = [aws_cognito_user_pool_client.expense_tracker_client.id]
    issuer   = "https://cognito-idp.${var.aws_region}.amazonaws.com/${aws_cognito_user_pool.expense_tracker.id}"
  }
}

resource "aws_apigatewayv2_integration" "add_expense_integration" {
  api_id                 = aws_apigatewayv2_api.expense_tracker_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.add_expense.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "get_expenses_integration" {
  api_id                 = aws_apigatewayv2_api.expense_tracker_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.get_expenses.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "delete_expense_integration" {
  api_id                 = aws_apigatewayv2_api.expense_tracker_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.delete_expense.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "post_expenses" {
  api_id             = aws_apigatewayv2_api.expense_tracker_api.id
  route_key          = "POST /expenses"
  target             = "integrations/${aws_apigatewayv2_integration.add_expense_integration.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito_authorizer.id
}

resource "aws_apigatewayv2_route" "get_expenses" {
  api_id             = aws_apigatewayv2_api.expense_tracker_api.id
  route_key          = "GET /expenses"
  target             = "integrations/${aws_apigatewayv2_integration.get_expenses_integration.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito_authorizer.id
}

resource "aws_apigatewayv2_route" "delete_expense" {
  api_id             = aws_apigatewayv2_api.expense_tracker_api.id
  route_key          = "DELETE /expenses/{id}"
  target             = "integrations/${aws_apigatewayv2_integration.delete_expense_integration.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito_authorizer.id
}

resource "aws_lambda_permission" "allow_apigw_add_expense" {
  statement_id  = "AllowAPIGatewayInvokeAdd"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.add_expense.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.expense_tracker_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "allow_apigw_get_expenses" {
  statement_id  = "AllowAPIGatewayInvokeGet"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_expenses.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.expense_tracker_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "allow_apigw_delete_expense" {
  statement_id  = "AllowAPIGatewayInvokeDelete"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.delete_expense.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.expense_tracker_api.execution_arn}/*/*"
}

output "api_gateway_url" {
  value = aws_apigatewayv2_api.expense_tracker_api.api_endpoint
}