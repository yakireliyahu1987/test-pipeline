terraform {
  backend "s3" {
    region  = "eu-central-1"
    bucket  = "tf-pipelines-state"
    key     = "sample-staging/terraform.tfstate"
    profile = "default"
  }
}

provider "aws" {
  region  = "eu-central-1"
  profile = "default"
}

module "vpc" {
  source = "../../modules/tf-module-generic-vpc"

  name = "sample-staging"
  cidr = "172.25.0.0/16"
}
