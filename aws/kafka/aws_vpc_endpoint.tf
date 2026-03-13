# aws_vpc_endpoint.tf

# #################################
# SG: Interface Endpoints
# #################################
resource "aws_security_group" "vpc_endpoint" {
  name        = "${var.project}-${var.env}-sg-vpc-endpoint"
  description = "Security group for VPC interface endpoints (ECR API/DKR)"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow HTTPS ingress"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    # security_groups = ["*"]
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  egress {
    description = "Allow all egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  tags = {
    Name = "${var.project}-${var.env}-sg-vpc-endpoint"
  }
}

# #################################
# VPC Endpoints:
# #################################
# VPC endpoint for ecr api
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.ecr.api"
  vpc_endpoint_type = "Interface"

  subnet_ids          = [for subnet in aws_subnet.private : subnet.id]
  security_group_ids  = [aws_security_group.vpc_endpoint.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.project}-${var.env}-vpc-endpoint-ecr-api"
  }
}

# VPC endpoint for ecr dkr
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.ecr.dkr"
  vpc_endpoint_type = "Interface"

  subnet_ids          = [for subnet in aws_subnet.private : subnet.id]
  security_group_ids  = [aws_security_group.vpc_endpoint.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.project}-${var.env}-vpc-endpoint-ecr-dkr"
  }
}

# VPC endpoint for image via S3
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"

  # default rt in private subnet
  route_table_ids = [
    aws_default_route_table.default.id,
  ]

  tags = {
    Name = "${var.project}-${var.env}-vpc-endpoint-s3"
  }
}

# VPC Endpoint for CloudWatch Logs
resource "aws_vpc_endpoint" "logs" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.logs"
  vpc_endpoint_type = "Interface"

  subnet_ids          = [for subnet in aws_subnet.private : subnet.id]
  security_group_ids  = [aws_security_group.vpc_endpoint.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.project}-${var.env}-vpc-endpoint-logs"
  }
}
