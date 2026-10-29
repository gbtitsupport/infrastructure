locals {
  # Add "prod" here when you're ready for a prod user pool
  cognito_environments  = toset(["test"])
  cognito_from_email    = "GBT Church <noreply@gbt-church.com>"
  ssm_parameter_default = "String"
}

resource "aws_cognito_user_pool" "this" {
  for_each = local.cognito_environments

  name                = "web-${each.key}"
  user_pool_tier      = "ESSENTIALS"
  deletion_protection = each.key == "prod" ? "ACTIVE" : "INACTIVE"

  # Email is the username, and it's trusted because only admins create users
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  # Invite only: no self sign-up
  admin_create_user_config {
    allow_admin_create_user_only = true
  }

  # Sign in with an emailed code. PASSWORD must stay in the list
  # (Cognito requires it), but users are never given one.
  sign_in_policy {
    allowed_first_auth_factors = ["PASSWORD", "EMAIL_OTP"]
  }

  # Unused by members, but must exist: make it strong
  password_policy {
    minimum_length    = 16
    require_lowercase = true
    require_uppercase = true
    require_numbers   = true
    require_symbols   = true
  }

  # Send codes through the SES domain defined in ses.tf
  email_configuration {
    email_sending_account = "DEVELOPER"
    source_arn            = aws_sesv2_email_identity.domain.arn
    from_email_address    = local.cognito_from_email
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }
}

resource "aws_cognito_user_pool_client" "web" {
  for_each = local.cognito_environments

  name         = "web-${each.key}"
  user_pool_id = aws_cognito_user_pool.this[each.key].id

  # Browser app: no client secret
  generate_secret = false

  explicit_auth_flows = [
    "ALLOW_USER_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]

  # Don't reveal whether an email is registered
  prevent_user_existence_errors = "ENABLED"

  access_token_validity  = 60
  id_token_validity      = 60
  refresh_token_validity = 30

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }
}

# The backend's env file loader reads everything under /web/<env>/
resource "aws_ssm_parameter" "cognito_user_pool_id" {
  for_each = local.cognito_environments

  name  = "/web/${each.key}/COGNITO_USER_POOL_ID"
  type  = local.ssm_parameter_default
  value = aws_cognito_user_pool.this[each.key].id
}

resource "aws_ssm_parameter" "cognito_client_id" {
  for_each = local.cognito_environments

  name  = "/web/${each.key}/COGNITO_CLIENT_ID"
  type  = local.ssm_parameter_default
  value = aws_cognito_user_pool_client.web[each.key].id
}

resource "aws_ssm_parameter" "cognito_region" {
  for_each = local.cognito_environments

  name  = "/web/${each.key}/COGNITO_REGION"
  type  = local.ssm_parameter_default
  value = "eu-west-1"
}

output "cognito_user_pool_ids" {
  value = { for env, pool in aws_cognito_user_pool.this : env => pool.id }
}

output "cognito_client_ids" {
  value = { for env, client in aws_cognito_user_pool_client.web : env => client.id }
}