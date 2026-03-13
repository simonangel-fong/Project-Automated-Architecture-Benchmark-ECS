# aws_ecs_svc_fastapi.tf

# #################################
# Variable
# #################################
locals {
  fastapi_log_id           = "/ecs/task/${var.project}-${var.env}-fastapi"
  fastapi_app_debug        = var.debug
  fastapi_log_level        = "WARNING"
  fastapi_ecr              = "${local.ecr_repo}:${var.svc_param.fastapi_svc.image_suffix}"
  fastapi_cpu              = var.svc_param.fastapi_svc.cpu
  fastapi_memory           = var.svc_param.fastapi_svc.memory
  fastapi_count_desired    = var.svc_param.fastapi_svc.count_desired
  fastapi_count_min        = var.svc_param.fastapi_svc.count_min
  fastapi_count_max        = var.svc_param.fastapi_svc.count_max
  fastapi_env_pool_size    = var.svc_param.fastapi_svc.container_env["pool_size"]
  fastapi_env_max_overflow = var.svc_param.fastapi_svc.container_env["max_overflow"]
  fastapi_env_worker       = var.svc_param.fastapi_svc.container_env["worker"]
  fastapi_env_pgdb_host    = aws_db_instance.postgres.address
  fastapi_env_pgdb_db      = aws_db_instance.postgres.db_name
  fastapi_env_pgdb_user    = aws_db_instance.postgres.username
  fastapi_env_pgdb_pwd     = aws_db_instance.postgres.password
  fastapi_threshold_cpu    = var.threshold_cpu
}

# #################################
# IAM: Task Execution Role
# #################################
# assume role
resource "aws_iam_role" "execution_role_fastapi" {
  name               = "${var.project}-${var.env}-execution-role-fastapi"
  assume_role_policy = data.aws_iam_policy_document.assume_role_ecs.json

  tags = {
    Project = var.project
    Role    = "ecs-task-execution-role-fastapi"
  }
}

# policy attachment: exec role
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy_fastapi" {
  role       = aws_iam_role.execution_role_fastapi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# #################################
# IAM: Task Role
# #################################
resource "aws_iam_role" "task_role_fastapi" {
  name               = "${var.project}-${var.env}-task-role-fastapi"
  assume_role_policy = data.aws_iam_policy_document.assume_role_ecs.json
}

# ##############################
# Security Group
# ##############################
resource "aws_security_group" "fastapi" {
  name        = "${var.project}-${var.env}-sg-fastapi"
  description = "App security group"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Allow load balancer to ingress"
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id] # limit source: alb
  }

  # Egress to vpc only
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-${var.env}-sg-fastapi"
  }
}

# #################################
# CloudWatch: log group
# #################################
resource "aws_cloudwatch_log_group" "log_group_fastapi" {
  name              = local.fastapi_log_id
  retention_in_days = 7
  kms_key_id        = aws_kms_key.cloudwatch_log.arn

  tags = {
    Name = local.fastapi_log_id
  }
}

# #################################
# ECS: Task Definition
# #################################
resource "aws_ecs_task_definition" "ecs_task_fastapi" {
  family                   = "${var.project}-${var.env}-task-fastapi"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = local.fastapi_cpu
  memory                   = local.fastapi_memory
  execution_role_arn       = aws_iam_role.execution_role_fastapi.arn
  task_role_arn            = aws_iam_role.task_role_fastapi.arn

  # method: template file
  container_definitions = templatefile("${path.module}/container/fastapi.tftpl", {
    project       = var.project
    region        = var.aws_region
    env           = var.env
    debug         = local.fastapi_app_debug
    log_level     = local.fastapi_log_level
    awslogs_group = local.fastapi_log_id
    image         = local.fastapi_ecr
    cpu           = local.fastapi_cpu
    memory        = local.fastapi_memory
    pgdb_host     = local.fastapi_env_pgdb_host
    pgdb_db       = local.fastapi_env_pgdb_db
    pgdb_user     = local.fastapi_env_pgdb_user
    pgdb_pwd      = local.fastapi_env_pgdb_pwd
    pool_size     = local.fastapi_env_pool_size
    max_overflow  = local.fastapi_env_max_overflow
    worker        = local.fastapi_env_worker
  })

  tags = {
    Name = "${var.project}-${var.env}-task-fastapi"
  }
}

# #################################
# ECS: Service
# #################################
resource "aws_ecs_service" "ecs_svc_fastapi" {
  name    = "${var.project}-${var.env}-service-fastapi"
  cluster = aws_ecs_cluster.ecs_cluster.id

  # task
  task_definition  = aws_ecs_task_definition.ecs_task_fastapi.arn
  desired_count    = local.fastapi_count_desired
  launch_type      = "FARGATE"
  platform_version = "LATEST"

  # network
  network_configuration {
    security_groups  = [aws_security_group.fastapi.id]
    subnets          = [for subnet in aws_subnet.private : subnet.id]
    assign_public_ip = false # disable public ip
  }

  # lb
  load_balancer {
    target_group_arn = aws_alb_target_group.fastapi_svc.arn
    container_name   = "fastapi"
    container_port   = 8000
  }

  tags = {
    Name = "${var.project}-${var.env}-service-fastapi"
  }

  # lifecycle {
  #   ignore_changes = [desired_count]
  # }

  depends_on = [
    aws_cloudwatch_log_group.log_group_fastapi,
    aws_vpc_endpoint.ecr_api,
    aws_vpc_endpoint.ecr_dkr,
    aws_vpc_endpoint.s3,
  ]
}

# #################################
# Service: Scaling policy
# #################################
# scale target
resource "aws_appautoscaling_target" "scale_target" {
  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.ecs_cluster.name}/${aws_ecs_service.ecs_svc_fastapi.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = local.fastapi_count_min
  max_capacity       = local.fastapi_count_max
}

# Alarm: cpu high
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.project}-${var.env}-cpu-alarm"
  namespace           = "AWS/ECS"
  period              = "30"
  evaluation_periods  = "2"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  statistic           = "Average"
  metric_name         = "CPUUtilization"
  threshold           = local.fastapi_threshold_cpu

  dimensions = {
    ClusterName = aws_ecs_cluster.ecs_cluster.name
    ServiceName = aws_ecs_service.ecs_svc_fastapi.name
  }

  alarm_actions = [aws_appautoscaling_policy.scale_up.arn]
}

# scale up policy
resource "aws_appautoscaling_policy" "scale_up" {
  name               = "${var.project}-${var.env}-scale-up"
  service_namespace  = aws_appautoscaling_target.scale_target.service_namespace
  resource_id        = aws_appautoscaling_target.scale_target.resource_id
  scalable_dimension = aws_appautoscaling_target.scale_target.scalable_dimension
  policy_type        = "StepScaling"

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 30
    metric_aggregation_type = "Maximum"

    step_adjustment {
      metric_interval_lower_bound = 0
      metric_interval_upper_bound = 5
      scaling_adjustment          = 1
    }

    step_adjustment {
      metric_interval_lower_bound = 5
      metric_interval_upper_bound = 10
      scaling_adjustment          = 2
    }

    step_adjustment {
      metric_interval_lower_bound = 10
      scaling_adjustment          = 3
    }
  }
}

# Alarm: cpu low
resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "${var.project}-${var.env}-cpu-low"
  namespace           = "AWS/ECS"
  period              = "30"
  evaluation_periods  = "2"
  comparison_operator = "LessThanThreshold"
  statistic           = "Average"
  metric_name         = "CPUUtilization"
  threshold           = local.fastapi_threshold_cpu - 10

  dimensions = {
    ClusterName = aws_ecs_cluster.ecs_cluster.name
    ServiceName = aws_ecs_service.ecs_svc_fastapi.name
  }
  alarm_actions = [aws_appautoscaling_policy.scale_down.arn]
}

resource "aws_appautoscaling_policy" "scale_down" {
  name               = "${var.project}-${var.env}-scale-down"
  service_namespace  = aws_appautoscaling_target.scale_target.service_namespace
  resource_id        = aws_appautoscaling_target.scale_target.resource_id
  scalable_dimension = aws_appautoscaling_target.scale_target.scalable_dimension
  policy_type        = "StepScaling"

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 180
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_upper_bound = 0
      scaling_adjustment          = -1
    }
  }
}
