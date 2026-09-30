output "role_name" {
  value = aws_iam_role.this.name
}

output "role_arn" {
  value = aws_iam_role.this.arn
}

output "instance_profile_name" {
  value = try(aws_iam_instance_profile.this[0].name, null)
}

output "attached_policy_arns" {
  value = values(local.policy_arns)
}