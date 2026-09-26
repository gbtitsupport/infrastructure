resource "aws_ecr_repository" "ecr_repository" {
  name                 = var.repo_name
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "ecr_lifecycle_policy" {
  repository = aws_ecr_repository.ecr_repository.name

  policy = jsonencode({
    rules = concat(
      [{
        rulePriority = 1
        description  = "Expire untagged after ${var.untagged_expiry_days} days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = var.untagged_expiry_days
        }
        action = { type = "expire" }
      }],
      [for i, r in var.tag_rules : {
        rulePriority = i + 2
        description  = "Keep last ${r.keep} ${r.prefix} images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = [r.prefix]
          countType     = "imageCountMoreThan"
          countNumber   = r.keep
        }
        action = { type = "expire" }
      }]
    )
  })
}