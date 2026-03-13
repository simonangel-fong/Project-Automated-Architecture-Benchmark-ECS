# aws_utils.tf
# ###############################
# ACM Certificate
# ###############################
# provider "aws" {
#   alias  = "us_east_1"
#   region = "us-east-1" # Required for CloudFront ACM
# }

# data "aws_acm_certificate" "cert" {
#   domain      = "*.${var.domain_name}"
#   provider    = aws.us_east_1
#   types       = ["AMAZON_ISSUED"]
#   most_recent = true
# }




# ##############################
# Data
# ##############################
data "aws_caller_identity" "current" {}

# ##############################
# KMS key
# ##############################
resource "aws_kms_key" "cloudwatch_log" {
  description             = "KMS CMK for CloudWatch Logs"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },

      # Allow CloudWatch Logs service to use this key
      {
        Sid    = "Allow CloudWatch Logs usage"
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.aws_region}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            # allow this key for any CW log group in the account
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:*"
          }
        }
      }
    ]
  })

  tags = {
    Name = "${var.project}-${var.env}-kms-logs"
  }
}

resource "aws_kms_alias" "cloudwatch_log" {
  name          = "alias/${var.project}-${var.env}-cloudwatch-logs"
  target_key_id = aws_kms_key.cloudwatch_log.key_id
}

