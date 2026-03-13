# ###############################
# ACM Certificate: https
# ###############################
provider "aws" {
  alias  = "ca_central_1"
  region = "ca-central-1" # Required for CloudFront ACM
}

data "aws_acm_certificate" "alb_cert" {
  domain      = "*.${var.domain_name}"
  provider    = aws.ca_central_1
  types       = ["AMAZON_ISSUED"]
  most_recent = true
}

# ##############################
# ALB SG
# ##############################
resource "aws_security_group" "alb" {
  name        = "${var.project}-${var.env}-sg-alb"
  description = "ALB security group"
  vpc_id      = aws_vpc.main.id

  # http
  ingress {
    description = "Allow HTTP ingress"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    # cidr_blocks = [aws_vpc.main.cidr_block]
  }

  # https
  ingress {
    description = "Allow HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    # cidr_blocks = [aws_vpc.main.cidr_block]
  }

  egress {
    description = "Allow all egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    # cidr_blocks = [aws_vpc.main.cidr_block]
  }

  tags = {
    Name = "${var.project}-${var.env}-sg-alb"
  }
}

# ##############################
# ALB
# ##############################
resource "aws_lb" "alb" {
  name               = "${var.project}-${var.env}-alb"
  load_balancer_type = "application"
  internal           = false

  subnets         = [for subnet in aws_subnet.public : subnet.id]
  security_groups = [aws_security_group.alb.id]

  # protect is true when prod
  enable_deletion_protection = false

  tags = {
    Name = "${var.project}-${var.env}-alb"
  }
}

# ##############################
# ALB Target Group
# ##############################
resource "aws_alb_target_group" "fastapi_svc" {
  name        = "${var.project}-${var.env}-tg"
  target_type = "ip"
  vpc_id      = aws_vpc.main.id
  port        = 8000
  protocol    = "HTTP"

  health_check {
    path                = "/api/health/"
    matcher             = "200-399"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# ##############################
# ALB listener
# ##############################
# Route traffic from the ALB to the target group
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = data.aws_acm_certificate.alb_cert.arn

  default_action {
    target_group_arn = aws_alb_target_group.fastapi_svc.arn
    type             = "forward"
  }
}
