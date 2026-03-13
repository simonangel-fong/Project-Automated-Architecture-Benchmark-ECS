# #################################
# aws_elasticache_redis.tf
# ElastiCache: Redis
# #################################

# #################################
# Locals
# #################################
locals {
  redis_port           = 6379
  redis_replication_id = "${var.project}-${var.env}-redis"
  redis_logging_name   = "${var.project}-${var.env}-log-group-redis"
}

# #################################
# Security Group for Redis
# #################################
resource "aws_security_group" "redis" {
  name        = "${var.project}-${var.env}-sg-redis"
  description = "Allow access to Redis from app services"
  vpc_id      = aws_vpc.main.id

  # Allow Redis traffic from FastAPI ECS tasks
  ingress {
    description = "Redis from FastAPI service"
    from_port   = local.redis_port
    to_port     = local.redis_port
    protocol    = "tcp"
    security_groups = [
      aws_security_group.fastapi.id, # allow FastAPI tasks
    ]
  }

  # Egress to anywhere inside VPC / internet as needed
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project}-${var.env}-sg-redis"
    Project = var.project
    Env     = var.env
  }
}

# #################################
# Subnet Group for Redis
# #################################
resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.project}-${var.env}-redis-subnet-group"
  subnet_ids = [for subnet in aws_subnet.private : subnet.id]

  tags = {
    Name    = "${var.project}-${var.env}-redis-subnet-group"
    Project = var.project
    Env     = var.env
  }
}

# #################################
# Parameter Group
# #################################
resource "aws_elasticache_parameter_group" "redis" {
  name        = "${var.project}-${var.env}-redis-params"
  family      = "redis7"
  description = "Parameter group for ${var.project}-${var.env} Redis"

  # Example overrides (keep or tweak as needed)
  # parameter {
  #   name  = "maxmemory-policy"
  #   value = "allkeys-lru"
  # }
}

# #################################
# Redis Replication Group
# #################################
resource "aws_elasticache_replication_group" "redis" {
  replication_group_id = local.redis_replication_id
  description          = "Redis for ${var.project}-${var.env} app"
  engine               = "redis"
  engine_version       = "7.1"
  node_type            = var.redis_node_type
  port                 = local.redis_port


  apply_immediately = true
  #   # Disable cluster mode, single shard
  #   automatic_failover_enabled    = false   # set true if you use replicas > 1
  #   multi_az_enabled              = false   # set true with replicas for HA
  #   num_cache_clusters            = var.redis_num_cache_nodes # e.g. 1

  parameter_group_name = aws_elasticache_parameter_group.redis.name
  subnet_group_name    = aws_elasticache_subnet_group.redis.name
  security_group_ids   = [aws_security_group.redis.id]

  #   at_rest_encryption_enabled    = true
  #   transit_encryption_enabled    = false   # set true + TLS config on client in prod

  #   maintenance_window            = "sun:03:00-sun:04:00"
  #   auto_minor_version_upgrade    = true

  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.redis.name
    destination_type = "cloudwatch-logs"
    log_format       = "text"
    log_type         = "slow-log"
  }
  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.redis.name
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "engine-log"
  }
}
