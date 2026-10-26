locals {
  domain    = "gbt-church.com"
  mail_from = "mail.${local.domain}"
}

data "aws_route53_zone" "main" {
  name = local.domain
}

resource "aws_sesv2_email_identity" "domain" {
  email_identity = local.domain
}

resource "aws_route53_record" "ses_dkim" {
  count   = 3
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "${aws_sesv2_email_identity.domain.dkim_signing_attributes[0].tokens[count.index]}._domainkey.${local.domain}"
  type    = "CNAME"
  ttl     = 600
  records = ["${aws_sesv2_email_identity.domain.dkim_signing_attributes[0].tokens[count.index]}.dkim.amazonses.com"]
}

# Custom MAIL FROM: better deliverability, and leaves your root SPF alone
resource "aws_sesv2_email_identity_mail_from_attributes" "domain" {
  email_identity         = aws_sesv2_email_identity.domain.email_identity
  mail_from_domain       = local.mail_from
  behavior_on_mx_failure = "USE_DEFAULT_VALUE"
}

resource "aws_route53_record" "mail_from_mx" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = local.mail_from
  type    = "MX"
  ttl     = 600
  records = ["10 feedback-smtp.eu-west-1.amazonses.com"]
}

resource "aws_route53_record" "mail_from_spf" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = local.mail_from
  type    = "TXT"
  ttl     = 600
  records = ["v=spf1 include:amazonses.com ~all"]
}

# For testing while still in the sandbox
resource "aws_sesv2_email_identity" "tester" {
  email_identity = "samsonispower@gmail.com"
}

output "ses_domain_identity_arn" {
  value = aws_sesv2_email_identity.domain.arn
}