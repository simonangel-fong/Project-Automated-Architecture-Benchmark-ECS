# ##############################
# APP
# ##############################
variable "project_name" {
  type    = string
  default = "ecs-benchmark"
}

variable "env" {
  type    = string
  default = "web"
}

# ##############################
# AWS
# ##############################
variable "aws_region" { type = string }

# ##############################
# Cloudflare
# ##############################
variable "cloudflare_api_token" { type = string }
variable "cloudflare_zone_id" { type = string }

variable "domain_name" { type = string }

locals {
  dns_record = "${var.project_name}.${var.domain_name}"
}
