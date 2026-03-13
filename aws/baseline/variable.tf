# ##############################
# APP
# ##############################
variable "project" {
  type    = string
  default = "auto-benchmark"
}

variable "env" {
  type    = string
  default = "baseline"
}

variable "debug" {
  type    = bool
  default = false
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

# ##############################
# AWS VPC
# ##############################
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

# ##############################
# AWS ECS
# ##############################
locals {
  ecr_repo = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.project}"
}

variable "threshold_cpu" {
  type    = number
  default = 35
}

variable "svc_param" {
  type = map(object({
    image_suffix  = string
    cpu           = number
    memory        = number
    count_desired = number
    count_min     = number
    count_max     = number
    container_env = map(any)
  }))
  default = {
    fastapi_svc = {
      image_suffix  = "fastapi-baseline"
      cpu           = 1024
      memory        = 2048
      count_desired = 1
      count_min     = 1
      count_max     = 1
      container_env = {
        pool_size    = 5
        max_overflow = 0
        worker       = 1
      }
    }
  }
}

variable "task_param" {
  type = map(object({
    image_suffix  = string
    cpu           = number
    memory        = number
    container_env = map(any)
    })
  )
  default = {
    flyway = {
      image_suffix  = "flyway"
      cpu           = 512
      memory        = 1024
      container_env = {}
    }
  }
}

# ##############################
# AWS RDS
# ##############################
variable "instance_class" {
  type    = string
  default = "db.t4g.medium"
}

variable "rds_max_connection" {
  type    = number
  default = 400
}

variable "db_name" {
  type = string
}

variable "db_username" {
  type = string
}

variable "db_password" {
  type = string
}

variable "db_app_pwd" {
  type = string
}

variable "db_readonly_pwd" {
  type = string
}

# ##############################
# AWS Cloudfront
# ##############################
variable "domain_name" {
  type    = string
  default = "arguswatcher.net"
}

locals {
  dns_record = "benchmark-${var.env}.${var.domain_name}"
}
