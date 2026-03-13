# #################################
# aws_rds.tf
# #################################

# #################################
# Variable
# #################################
locals {
  rds_postgres_identifier  = "${var.project}-${var.env}-rds-pgdb"
  rds_postgres_param_group = "${var.project}-${var.env}-rds-param-group-pgdb"
}

# ##############################
# Security Group
# ##############################
resource "aws_security_group" "postgres" {
  name        = "${var.project}-${var.env}-sg-postgres"
  description = "Allow fastapi to access pgdb"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "ingress from fastapi to Postgres"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    security_groups = [
      aws_security_group.fastapi.id, # allow fastapi
      aws_security_group.flyway.id,  # allow flyway
    ]
    # cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "egress to anywhere"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    # cidr_blocks = ["0.0.0.0/0"]
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  tags = {
    Name = "${var.project}-${var.env}-sg-postgres"
  }
}

# ##############################
# Subnet Group
# ##############################
resource "aws_db_subnet_group" "postgres" {
  name = "${var.project}-${var.env}-db-subnet"

  subnet_ids = [
    for subnet in aws_subnet.private : subnet.id
  ]

  tags = {
    Name = "${var.project}-${var.env}-db-subnet"
  }
}

# ##############################
# Parameter Group
# ##############################
resource "aws_db_parameter_group" "postgres" {
  name   = local.rds_postgres_param_group
  family = "postgres17"

  parameter {
    name         = "max_connections"
    value        = var.rds_max_connection
    apply_method = "pending-reboot"
  }

  parameter {
    name  = "timezone"
    value = "America/Toronto"
  }
}

# ##############################
# AWS RDS
# ##############################
resource "aws_db_instance" "postgres" {
  identifier = local.rds_postgres_identifier

  # DBA
  engine               = "postgres"
  engine_version       = "17.6"
  parameter_group_name = aws_db_parameter_group.postgres.name
  apply_immediately    = true # apply modifications right away

  # backup
  skip_final_snapshot      = true
  backup_retention_period  = 0 # no backups for dev/testing
  delete_automated_backups = true
  deletion_protection      = false

  # hardware
  instance_class    = var.instance_class
  allocated_storage = 20
  storage_type      = "gp3"

  # Credentials
  username = var.db_username
  password = var.db_password
  db_name  = var.db_name

  # Networking
  publicly_accessible    = false
  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  vpc_security_group_ids = [aws_security_group.postgres.id]

  # Encryption
  storage_encrypted = true

  # loging
  enabled_cloudwatch_logs_exports = ["postgresql"] # enable export log

  # monitoring
  monitoring_interval = 60 # every 60s
  monitoring_role_arn = aws_iam_role.rds_assume_role.arn

  tags = {
    Name = "${var.project}-${var.env}-rds-pgdb"
  }

  # depends_on = [
  #   aws_cloudwatch_log_group.rds_postgres
  # ]
}
