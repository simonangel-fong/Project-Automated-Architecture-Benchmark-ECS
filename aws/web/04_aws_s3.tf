# aws_s3.tf

locals {
  bucket_name   = "${var.project_name}.${var.domain_name}"
  web_file_path = "../../app/html"
}

data "aws_s3_bucket" "web" {
  bucket = local.bucket_name
}

# ########################################
# S3 bucket Configuration
# ########################################
# Enabe bucket versioning
resource "aws_s3_bucket_versioning" "web" {
  bucket = data.aws_s3_bucket.web.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable static website hosting
resource "aws_s3_bucket_website_configuration" "web" {
  bucket = data.aws_s3_bucket.web.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

# Permission
# Enable bucket public access block
resource "aws_s3_bucket_public_access_block" "web" {
  bucket = data.aws_s3_bucket.web.id

  block_public_acls       = false
  ignore_public_acls      = false
  block_public_policy     = false
  restrict_public_buckets = false
}

# set ownership
resource "aws_s3_bucket_ownership_controls" "web" {
  bucket = data.aws_s3_bucket.web.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# set access control list
resource "aws_s3_bucket_acl" "web" {
  bucket = data.aws_s3_bucket.web.id
  acl    = "public-read"

  depends_on = [
    aws_s3_bucket_ownership_controls.web,
    aws_s3_bucket_public_access_block.web
  ]
}

# Enable bucket policy for public read access
resource "aws_s3_bucket_policy" "web" {
  bucket = data.aws_s3_bucket.web.id

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : "*",
        "Action" : "s3:GetObject",
        "Resource" : "arn:aws:s3:::${data.aws_s3_bucket.web.id}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.web]
}

# ########################################
# Upload web files
# ########################################
module "web_file" {
  source = "hashicorp/dir/template"

  base_dir = local.web_file_path
}

# filter video
locals {
  filtered_files = {
    for path, file in module.web_file.files : path => file if !startswith(path, "video")
  }
}

# update S3 object resource for hosting bucket files
resource "aws_s3_object" "web_file" {
  bucket = data.aws_s3_bucket.web.id

  # loop all files
  for_each     = local.filtered_files
  key          = each.key
  content_type = each.value.content_type

  source  = each.value.source_path
  content = each.value.content

  # ETag of the S3 object
  etag = each.value.digests.md5
}

