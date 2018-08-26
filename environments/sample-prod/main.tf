terraform {
  backend "s3" {
    region  = "eu-central-1"
    bucket  = "tf-pipelines-state"
    key     = "sample-prod/terraform.tfstate"
    profile = "default"
  }
}

provider "aws" {
  region  = "eu-central-1"
  profile = "default"
}

module "vpc" {
  source = "../../modules/tf-module-generic-vpc"

  name = "sample-prod"
  cidr = "172.20.0.0/16"
}
