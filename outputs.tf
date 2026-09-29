output "cognito_user_pool_id" {
  value = module.expense_tracker.cognito_user_pool_id
}

output "cognito_client_id" {
  value = module.expense_tracker.cognito_client_id
}

output "cognito_hosted_ui_domain" {
  value = module.expense_tracker.cognito_hosted_ui_domain
}

output "cognito_user_pool_arn" {
  value = module.expense_tracker.cognito_user_pool_arn
}

output "dynamodb_table_name" {
  value = module.expense_tracker.dynamodb_table_name
}

output "dynamodb_table_arn" {
  value = module.expense_tracker.dynamodb_table_arn
}

output "add_expense_function_name" {
  value = module.expense_tracker.add_expense_function_name
}

output "get_expenses_function_name" {
  value = module.expense_tracker.get_expenses_function_name
}

output "delete_expense_function_name" {
  value = module.expense_tracker.delete_expense_function_name
}

output "add_expense_invoke_arn" {
  value = module.expense_tracker.add_expense_invoke_arn
}

output "get_expenses_invoke_arn" {
  value = module.expense_tracker.get_expenses_invoke_arn
}

output "delete_expense_invoke_arn" {
  value = module.expense_tracker.delete_expense_invoke_arn
}

output "api_gateway_url" {
  value = module.expense_tracker.api_gateway_url
}

output "website_url" {
  value = module.expense_tracker.website_url
}

output "cloudfront_url" {
  value = module.expense_tracker.cloudfront_url
}

output "cloudfront_distribution_id" {
  value = module.expense_tracker.cloudfront_distribution_id
}