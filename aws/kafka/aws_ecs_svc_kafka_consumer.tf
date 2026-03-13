# aws_ecs_svc_kafka_consumer.tf

# #################################
# Variable
# #################################
locals {
  kafka_consumer_log_id             = "/ecs/task/${var.project}-${var.env}-kafka-consumer"
  kafka_consumer_ecr                = "${local.ecr_repo}:${var.svc_param.kafka_consumer_svc.image_suffix}"
  kafka_log_level                   = "WARNING"
  kafka_use_msk_auth                = true
  kafka_consumer_cpu                = var.svc_param.kafka_consumer_svc.cpu
  kafka_consumer_memory             = var.svc_param.kafka_consumer_svc.memory
  kafka_consumer_desired            = var.svc_param.kafka_consumer_svc.count_desired
  kafka_consumer_min                = var.svc_param.kafka_consumer_svc.count_min
  kafka_consumer_max                = var.svc_param.kafka_consumer_svc.count_max
  kafka_consumer_env_pool_size      = var.svc_param.kafka_consumer_svc.container_env["pool_size"]
  kafka_consumer_env_max_overflow   = var.svc_param.kafka_consumer_svc.container_env["max_overflow"]
  kafka_consumer_env_pgdb_host      = aws_db_instance.postgres.address
  kafka_consumer_env_pgdb_db        = aws_db_instance.postgres.db_name
  kafka_consumer_env_pgdb_user      = aws_db_instance.postgres.username
  kafka_consumer_env_pgdb_pwd       = aws_db_instance.postgres.password
  kafka_consumer_env_kafka_topic    = var.kafka_topic
  kafka_consumer_env_kafka_group_id = var.svc_param.kafka_consumer_svc.container_env["group_id"]
  kafka_consumer_scale_cpu          = var.threshold_cpu
}

# #################################
# IAM: Task Execution Role
# #################################
resource "aws_iam_role" "consumer_task_execution_role" {
  name               = "${var.project}-${var.env}-task-execution-role-consumer"
  assume_role_policy = data.aws_iam_policy_document.assume_role_ecs.json
}

# policy attachment: exec role
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy_consumer" {
  role       = aws_iam_role.consumer_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# #################################
# IAM: Task Role
# #################################
resource "aws_iam_role" "consumer_task_role" {
  name               = "${var.project}-${var.env}-task-role-consumer"
  assume_role_policy = data.aws_iam_policy_document.assume_role_ecs.json
}

# policy attachment: consumer with msk
data "aws_iam_policy_document" "consumer_msk" {
  # cluster
  statement {
    sid    = "KafkaClusterConnectAndDescribe"
    effect = "Allow"
    actions = [
      "kafka-cluster:Connect",
      "kafka-cluster:DescribeCluster",
      "kafka-cluster:DescribeClusterDynamicConfiguration",
    ]
    resources = [
      "arn:aws:kafka:${var.aws_region}:${data.aws_caller_identity.current.account_id}:cluster/${aws_msk_cluster.kafka.cluster_name}/${aws_msk_cluster.kafka.cluster_uuid}"
    ]
  }

  # topic
  statement {
    sid    = "KafkaTopicReadTelemetry"
    effect = "Allow"
    actions = [
      "kafka-cluster:DescribeTopic",
      "kafka-cluster:DescribeTopicDynamicConfiguration",
      "kafka-cluster:ReadData",
    ]
    resources = [
      "arn:aws:kafka:${var.aws_region}:${data.aws_caller_identity.current.account_id}:topic/${aws_msk_cluster.kafka.cluster_name}/${aws_msk_cluster.kafka.cluster_uuid}/telemetry"
    ]
  }

  # Group
  statement {
    sid    = "KafkaConsumerGroupAccess"
    effect = "Allow"
    actions = [
      "kafka-cluster:DescribeGroup",
      "kafka-cluster:AlterGroup",
    ]
    resources = [
      "arn:aws:kafka:${var.aws_region}:${data.aws_caller_identity.current.account_id}:group/${aws_msk_cluster.kafka.cluster_name}/${aws_msk_cluster.kafka.cluster_uuid}/${local.kafka_consumer_env_kafka_group_id}"
    ]
  }
}

resource "aws_iam_policy" "consumer_msk" {
  name   = "${var.project}-${var.env}-consumer-msk"
  policy = data.aws_iam_policy_document.consumer_msk.json
}

resource "aws_iam_role_policy_attachment" "consumer_msk" {
  role       = aws_iam_role.consumer_task_role.name
  policy_arn = aws_iam_policy.consumer_msk.arn
}

# ##############################
# Security Group
# ##############################
resource "aws_security_group" "consumer" {
  name        = "${var.project}-${var.env}-sg-consumer"
  description = "Consumer security group"
  vpc_id      = aws_vpc.main.id

  # no ingress needed
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-${var.env}-sg-consumer"
  }
}

# #################################
# CloudWatch: log group
# #################################
resource "aws_cloudwatch_log_group" "log_group_consumer" {
  name              = local.kafka_consumer_log_id
  retention_in_days = 7
  kms_key_id        = aws_kms_key.cloudwatch_log.arn

  tags = {
    Name = local.kafka_consumer_log_id
  }
}

# #################################
# ECS: Task Definition
# #################################
resource "aws_ecs_task_definition" "ecs_task_consumer" {
  family                   = "${var.project}-${var.env}-task-consumer"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = local.kafka_consumer_cpu
  memory                   = local.kafka_consumer_memory

  execution_role_arn = aws_iam_role.consumer_task_execution_role.arn
  task_role_arn      = aws_iam_role.consumer_task_role.arn

  container_definitions = templatefile("${path.module}/container/kafka_consumer.tftpl", {
    project         = var.project
    region          = var.aws_region
    env             = var.env
    debug           = var.debug
    log_level       = local.kafka_log_level
    use_msk_auth    = local.kafka_use_msk_auth
    image           = local.kafka_consumer_ecr
    cpu             = local.kafka_consumer_cpu
    memory          = local.kafka_consumer_memory
    awslogs_group   = local.kafka_consumer_log_id
    pgdb_host       = local.kafka_consumer_env_pgdb_host
    pgdb_db         = local.kafka_consumer_env_pgdb_db
    pgdb_user       = local.kafka_consumer_env_pgdb_user
    pgdb_pwd        = local.kafka_consumer_env_pgdb_pwd
    pool_size       = local.kafka_consumer_env_pool_size
    max_overflow    = local.kafka_consumer_env_max_overflow
    kafka_bootstrap = aws_msk_cluster.kafka.bootstrap_brokers_sasl_iam
    kafka_group_id  = local.kafka_consumer_env_kafka_group_id
    kafka_topic     = local.kafka_consumer_env_kafka_topic
  })

  tags = {
    Name = "${var.project}-${var.env}-task-consumer"
  }
}

# #################################
# ECS: Service
# #################################
resource "aws_ecs_service" "ecs_svc_consumer" {
  name    = "${var.project}-${var.env}-service-consumer"
  cluster = aws_ecs_cluster.ecs_cluster.id

  task_definition  = aws_ecs_task_definition.ecs_task_consumer.arn
  desired_count    = local.kafka_consumer_desired
  launch_type      = "FARGATE"
  platform_version = "LATEST"

  network_configuration {
    security_groups  = [aws_security_group.consumer.id]
    subnets          = [for subnet in aws_subnet.private : subnet.id]
    assign_public_ip = false
  }

  tags = {
    Name = "${var.project}-${var.env}-service-consumer"
  }

  depends_on = [
    aws_cloudwatch_log_group.log_group_consumer,
  ]
}

# #################################
# Service: Scaling policy
# #################################
resource "aws_appautoscaling_target" "scaling_target_kafka_consumer" {
  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.ecs_cluster.name}/${aws_ecs_service.ecs_svc_consumer.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = local.kafka_consumer_min
  max_capacity       = local.kafka_consumer_max
}

# scaling policy: cpu
resource "aws_appautoscaling_policy" "scaling_cpu_kafka_consumer" {
  name               = "${var.project}-scale-cpu-kafka-consumer"
  resource_id        = aws_appautoscaling_target.scaling_target_kafka_consumer.resource_id
  scalable_dimension = aws_appautoscaling_target.scaling_target_kafka_consumer.scalable_dimension
  service_namespace  = aws_appautoscaling_target.scaling_target_kafka_consumer.service_namespace
  policy_type        = "TargetTrackingScaling"

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = local.kafka_consumer_scale_cpu # cpu%
    scale_in_cooldown  = 30
    scale_out_cooldown = 30
  }
}



