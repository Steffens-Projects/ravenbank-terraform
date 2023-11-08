provider "aws" {
  region = "us-east-1"
}

terraform {
  backend "s3" {
    bucket         = "steffen-terraform-s3-remote-state"
    key            = "global/backend/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-locking"
    encrypt        = true
  }
}