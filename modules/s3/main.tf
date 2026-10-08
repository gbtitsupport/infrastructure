
data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "s3_bucket" {
  bucket = "cms-uploads-${var.environment}-${data.aws_caller_identity.current.account_id}"
}


resource "aws_s3_bucket_website_configuration" "s3_bucket_website_configuration" {
  count  = var.enable_website ? 1 : 0
  bucket = aws_s3_bucket.s3_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

resource "aws_s3_bucket_public_access_block" "public_access_block" {
  bucket = aws_s3_bucket.s3_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false

  depends_on = [aws_s3_bucket.s3_bucket]
}


resource "aws_s3_bucket_policy" "policy" {
  bucket = aws_s3_bucket.s3_bucket.id
  policy = jsonencode({
    Id = "${aws_s3_bucket.s3_bucket.id}BucketPolicy"
    Statement = [
      {
        Action = var.policy_action
        Effect = var.policy_effect
        Principal = {
          AWS = var.policy_principal
        }
        Resource = [aws_s3_bucket.bucket.arn,"${aws_s3_bucket.bucket.arn}/*",]
        Sid      = var.policy_sid
      }
    ]
    Version = "2012-10-17"
  })
  depends_on = [
    aws_s3_bucket.bucket,
    aws_s3_bucket_public_access_block.public_access_block
  ]
}
