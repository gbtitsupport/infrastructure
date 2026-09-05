provider "aws" {
  region = "eu-west-1"

  default_tags {
    tags = {
      Project     = "gbt cloud infrastructure"
      ManagedBy   = "terraform"
      Owner       = "pipeline-deployer "
    }
  }
}
