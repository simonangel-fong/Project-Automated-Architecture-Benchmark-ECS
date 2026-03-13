# aws_vpc.tf

# ##############################
# VPC
# ##############################
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project}-${var.env}-vpc"
  }
}

# ##############################
# Internet Gateway
# ##############################
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project}-${var.env}-igw"
  }
}

# ##############################
# Route Table
# ##############################
# rt: default, private
resource "aws_default_route_table" "default" {
  default_route_table_id = aws_vpc.main.default_route_table_id

  tags = {
    Name = "${var.project}-${var.env}-default-rt-private"
  }
}

# rt public
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.project}-${var.env}-rt-public"
  }
}

# ##############################
# AZ
# ##############################
data "aws_availability_zones" "available" {
  state = "available"
}

# ##############################
# Private subnet
# ##############################
resource "aws_subnet" "private" {
  for_each = toset(data.aws_availability_zones.available.names)

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, index(data.aws_availability_zones.available.names, each.value) + 10)
  availability_zone = each.value

  tags = {
    Name = "${var.project}-${var.env}-${each.value}-private-subnet"
  }
}

# ##############################
# Public subnet
# ##############################
resource "aws_subnet" "public" {
  for_each = toset(data.aws_availability_zones.available.names)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, index(data.aws_availability_zones.available.names, each.value) + 100)
  availability_zone       = each.value
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project}-${var.env}-${each.value}-public-subnet"
  }
}

# ##############################
# Route Table Associations
# ##############################
resource "aws_route_table_association" "default" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_default_route_table.default.id
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}
