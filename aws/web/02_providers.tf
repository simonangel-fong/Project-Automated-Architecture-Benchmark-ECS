# provider.tf
provider "aws" {
  region = var.aws_region

  # default tags  
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.env
      ManagedBy   = "terraform"
    }
  }
}

# acm certificate
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

# Configure the cloudflare Provider
provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
