
# aws_cf.tf

locals {
  cloudfront_name = "${var.project_name}.${var.domain_name}"
}

data "aws_region" "current" {}

data "aws_acm_certificate" "cf_certificate" {
  domain      = "*.${var.domain_name}"
  provider    = aws.us_east_1
  types       = ["AMAZON_ISSUED"]
  most_recent = true
}

# ###############################
# CloudFront
# ###############################
resource "aws_cloudfront_distribution" "web" {

  # s3 web hosting
  origin {
    origin_id   = local.bucket_name
    domain_name = data.aws_s3_bucket.web.bucket_regional_domain_name

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only" # S3 website endpoint supports HTTP only
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # default cache: s3 web
  default_cache_behavior {
    target_origin_id       = local.bucket_name
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    compress               = true

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  enabled             = true
  default_root_object = "index.html"
  aliases             = ["${local.dns_record}"]
  price_class         = "PriceClass_100"

  viewer_certificate {
    acm_certificate_arn      = data.aws_acm_certificate.cf_certificate.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Name = local.cloudfront_name
  }
}
