terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"

  # Tag all resources
  default_tags {
    tags = {
      "Terraform" = "true"
      "Repo"      = "terraform-aws-lambda-sns-sqs"
    }
  }
}

data "aws_caller_identity" "current" {}

# https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-53r5.pdf
