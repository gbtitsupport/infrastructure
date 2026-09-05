terraform {
  backend "s3" {
    bucket         = "gbt-infra-terraform-state-b7820b85"
    key            = "cc176c7d.terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "terraform-state-locks"
    encrypt        = true
  }
}