terraform {
  backend "s3" {
    bucket         = "gbt-infra-terraform-state-b7820b85"
    key            = "test/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "terraform-state-locks"
    encrypt        = true
  }
}



# STATE FOR TEST ENVIRONMENT
# STATE FOR TEST ENVIRONMENT
# STATE FOR TEST ENVIRONMENT