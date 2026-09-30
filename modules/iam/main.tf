locals {
  toggled_policies = merge(
    var.attach_ssm ? {
      ssm = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    } : {},
    var.attach_ecr_pull ? {
      ecr_pull = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
    } : {},
  )

  policy_arns = merge(local.toggled_policies, var.additional_policy_arns)

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role" "this" {
  name_prefix        = var.name_prefix
  assume_role_policy = local.assume_role_policy
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "this" {
  for_each = local.policy_arns

  role       = aws_iam_role.this.name
  policy_arn = each.value
}

resource "aws_iam_role_policy" "inline" {
  count = var.inline_policy_json == null ? 0 : 1

  name_prefix = "${var.name_prefix}inline-"
  role        = aws_iam_role.this.id
  policy      = var.inline_policy_json
}

resource "aws_iam_instance_profile" "this" {
  count = var.create_instance_profile ? 1 : 0

  name_prefix = var.name_prefix
  role        = aws_iam_role.this.name
  tags        = var.tags
}