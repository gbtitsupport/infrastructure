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

//  ecr provisioning

module "ecr" {
  source = "../modules/ecr"

  repo_name = "gbt-artifacts"
  tag_rules = [
    { prefix = "test", keep = 10 }
  ]
}

// ec2 provisioning
module "ec2" {
  source        = "../modules/ec2"
  instance_type = "t4g.micro"
  environment   = "test"
}

// dynamodb provisiong

module "dynamodb" {
  source        = "../modules/dynamo_db"
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