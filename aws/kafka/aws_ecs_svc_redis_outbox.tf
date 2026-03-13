# aws_ecs_svc_redis_outbox.tf

# #################################
# Variable
# #################################
locals {
  redis-outbox_log_id           = "/ecs/task/${var.project}-${var.env}-redis-outbox"
  redis-outbox_ecr              = "${local.ecr_repo}:${var.svc_param.redis-outbox_svc.image_suffix}"
  redis-outbox_log_level        = "WARNING"
  redis-outbox_cpu              = var.svc_param.redis-outbox_svc.cpu
  redis-outbox_memory           = var.svc_param.redis-outbox_svc.memory
  redis-outbox_desired          = var.svc_param.redis-outbox_svc.count_desired
  redis-outbox_env_pool_size    = var.svc_param.redis-outbox_svc.container_env["pool_size"]
  redis-outbox_env_max_overflow = var.svc_param.redis-outbox_svc.container_env["max_overflow"]
  redis-outbox-poll_interval    = var.poll_interval
}

# #################################
# IAM: Execution Role
# #################################
# assume role
resource "aws_iam_role" "execution_role_outbox" {
  name               = "${var.project}-${var.env}-execution-role-redis-outbox"
  assume_role_policy = data.aws_iam_policy_document.assume_role_ecs.json

  tags = {
    Project = var.project
    Role    = "ecs-task-execution-role"
  }
}

# policy attachment: exec role
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy_outbox" {
  role       = aws_iam_role.execution_role_outbox.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# #################################
# IAM: Task Role
# #################################
resource "aws_iam_role" "outbox_task_role" {
  name               = "${var.project}-${var.env}-task-role-redis-outbox"
  assume_role_policy = data.aws_iam_policy_document.assume_role_ecs.json
}

# ##############################
# Security Group
# ##############################
resource "aws_security_group" "redis-outbox" {
  name        = "${var.project}-${var.env}-sg-redis-outbox"
  description = "Redis outbox security group"
  vpc_id      = aws_vpc.main.id

  # no ingress needed
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-${var.env}-sg-redis-outbox"
  }
}

# #################################
# CloudWatch: log group
# #################################
resource "aws_cloudwatch_log_group" "log_group_outbox" {
  name              = local.redis-outbox_log_id
  retention_in_days = 7
  kms_key_id        = aws_kms_key.cloudwatch_log.arn

  tags = {
    Name = local.redis-outbox_log_id
  }
}

# #################################
# ECS: Task Definition
# #################################
resource "aws_ecs_task_definition" "ecs_task_redis-outbox" {
  family                   = "${var.project}-${var.env}-task-redis-outbox"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = local.redis-outbox_cpu
  memory                   = local.redis-outbox_memory

  execution_role_arn = aws_iam_role.execution_role_outbox.arn
  task_role_arn      = aws_iam_role.outbox_task_role.arn

  container_definitions = templatefile("${path.module}/container/redis_outbox.tftpl", {
    project       = var.project
    region        = var.aws_region
    env           = var.env
    debug         = var.debug
    log_level     = local.redis-outbox_log_level
    awslogs_group = local.redis-outbox_log_id

    image        = local.redis-outbox_ecr
    cpu          = local.redis-outbox_cpu
    memory       = local.redis-outbox_memory
    pool_size    = local.redis-outbox_env_pool_size
    max_overflow = local.redis-outbox_env_max_overflow
    worker       = local.fastapi_env_worker

    pgdb_host = aws_db_instance.postgres.address
    pgdb_db   = aws_db_instance.postgres.db_name
    pgdb_user = aws_db_instance.postgres.username
    pgdb_pwd  = aws_db_instance.postgres.password

    redis_host    = aws_elasticache_replication_group.redis.primary_endpoint_address
    redis_port    = aws_elasticache_replication_group.redis.port
    poll_interval = local.redis-outbox-poll_interval
  })

  tags = {
    Name = "${var.project}-${var.env}-task-redis-outbox"
  }
}

# #################################
# ECS: Service
# #################################
resource "aws_ecs_service" "ecs_svc_redis-outbox" {
  name    = "${var.project}-${var.env}-service-redis-outbox"
  cluster = aws_ecs_cluster.ecs_cluster.id

  task_definition  = aws_ecs_task_definition.ecs_task_redis-outbox.arn
  desired_count    = local.redis-outbox_desired
  launch_type      = "FARGATE"
  platform_version = "LATEST"

  network_configuration {
    security_groups  = [aws_security_group.redis-outbox.id]
    subnets          = [for subnet in aws_subnet.private : subnet.id]
    assign_public_ip = false
  }

  tags = {
    Name = "${var.project}-${var.env}-service-redis-outbox"
  }

  depends_on = [
    aws_cloudwatch_log_group.log_group_outbox,
  ]
}
