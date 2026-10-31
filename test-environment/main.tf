provider "aws" {
  region = "eu-west-1"

  default_tags {
    tags = {
      Project     = "gbt-cloud-infrastructure"
      ManagedBy   = "terraform"
      Owner       = "pipeline-deployer"
      Environment = "test"
    }
  }
}


locals {
  environment = "test"
  region      = "eu-west-1"
  table_base  = "cms-db"

  app_params = {
    ENVIRONMENT         = local.environment
    REGION              = local.region
    DYNAMODB_TABLE_NAME = "${local.table_base}-${local.environment}"
  }
}

// ec2 provisioning
module "ec2" {
  source        = "../modules/ec2"
  instance_type = "t4g.micro"
}


// lookup for hosted zones
data "aws_route53_zone" "zone" {
  name = "gbt-church.com"
}

resource "aws_route53_record" "web_api_test" {
  zone_id         = data.aws_route53_zone.zone.zone_id
  name            = "test.api.gbt-church.com"
  type            = "A"
  ttl             = 60
  records         = [module.ec2.public_ip]
  allow_overwrite = true
}

// dynamodb provisiong

module "dynamodb" {
  source      = "../modules/dynamo_db"
  environment = local.app_params.ENVIRONMENT
  name        = local.app_params.DYNAMODB_TABLE_NAME
}

//s3 bucket 

module "s3-object-test" {
  source           = "../modules/s3"
  environment      = "test"
  enable_website   = false
  policy_action    = ["s3:GetObject", "s3:PutObject"]
  policy_effect    = "Allow"
  policy_principal = "*"
  policy_sid       = "PublicReadGetObject"
}

resource "aws_ssm_parameter" "app" {
  for_each = local.app_params

  name  = "/web/test/${each.key}"
  type  = "String"
  value = each.value
}