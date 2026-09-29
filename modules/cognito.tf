resource "aws_cognito_user_pool" "expense_tracker" {
  name = "${var.project_name}-user-pool"

  username_attributes      = []
  auto_verified_attributes = ["email"]

  username_configuration {
    case_sensitive = false
  }

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_uppercase = true
    require_numbers   = true
    require_symbols   = false
  }

  schema {
    name                     = "email"
    attribute_data_type      = "String"
    required                 = true
    mutable                  = true
    developer_only_attribute = false

    string_attribute_constraints {
      min_length = 5
      max_length = 256
    }
  }

  verification_message_template {
    default_email_option = "CONFIRM_WITH_CODE"
    email_subject        = "Verify your Expense Tracker account"
    email_message        = "Your verification code is {####}"
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  tags = {
    Project = var.project_name
  }
}

resource "aws_cognito_user_pool_client" "expense_tracker_client" {
  name         = "${var.project_name}-app-client"
  user_pool_id = aws_cognito_user_pool.expense_tracker.id

  generate_secret = false

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH"
  ]

  callback_urls = [
    "http://localhost:3000",
    "https://${aws_cloudfront_distribution.frontend.domain_name}"
  ]
  logout_urls = [
    "http://localhost:3000",
    "https://${aws_cloudfront_distribution.frontend.domain_name}"
  ]

  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["openid", "email", "profile"]
  allowed_oauth_flows_user_pool_client = true
  supported_identity_providers         = ["COGNITO"]

  access_token_validity  = 1
  id_token_validity      = 1
  refresh_token_validity = 30

  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }

  prevent_user_existence_errors = "ENABLED"
}

resource "aws_cognito_user_pool_domain" "expense_tracker_domain" {
  domain       = "${var.project_name}-app"
  user_pool_id = aws_cognito_user_pool.expense_tracker.id
}

output "cognito_hosted_ui_domain" {
  value = "https://${aws_cognito_user_pool_domain.expense_tracker_domain.domain}.auth.${var.aws_region}.amazoncognito.com"
}

output "cognito_user_pool_id" {
  value = aws_cognito_user_pool.expense_tracker.id
}

output "cognito_client_id" {
  value = aws_cognito_user_pool_client.expense_tracker_client.id
}

output "cognito_user_pool_arn" {
  value = aws_cognito_user_pool.expense_tracker.arn
}