terraform {
  backend "s3" {
    region  = "eu-central-1"
    bucket  = "tf-pipelines-state"
    key     = "sample-dev/terraform.tfstate"
    profile = "default"
  }
}

provider "aws" {
  region  = "eu-central-1"
  profile = "default"
}

module "vpc" {
  source = "../../modules/tf-module-generic-vpc"

  name = "sample-dev"
  cidr = "172.17.0.0/16"
}
