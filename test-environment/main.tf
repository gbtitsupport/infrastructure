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