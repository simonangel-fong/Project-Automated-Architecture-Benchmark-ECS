terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }

    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }

  }

  required_version = ">= 1.9.8"

  backend "s3" {
    bucket  = ""
    key     = ""
    region  = ""
    encrypt = true
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region

  # default tags  
  default_tags {
    tags = {
      Project     = var.project
      Environment = var.env
      ManagedBy   = "terraform"
    }
  }
}

# Configure the cloudflare Provider
provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
