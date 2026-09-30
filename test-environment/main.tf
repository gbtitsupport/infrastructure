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

module "ecr" {
  source = "../modules/ecr"

  repo_name = "gbt-artifacts"
  tag_rules = [
    { prefix = "test", keep = 10 }
  ]
}

module "iam_role" {
  source = "../modules/iam"

  name_prefix     = "gbt-web-"
  attach_ssm      = true
  attach_ecr_pull = true
}

module "ec2" {
  source        = "../modules/ec2"
  instance_type = "t4g.micro"
  tags = {
    App = "test-content-service"
  }
}