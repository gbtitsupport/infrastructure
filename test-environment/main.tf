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
  environment = "test"
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