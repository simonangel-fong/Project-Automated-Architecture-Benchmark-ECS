# aws_ecs_svc_kafka_init.tf


# #################################
# Variable
# #################################
locals {
  kafka_init_log_id              = "/ecs/task/${var.project}-${var.env}-kafka-init"
  kafka_init_ecr                 = "${local.ecr_repo}:${var.task_param.kafka_init.image_suffix}"
  kafka_init_cpu                 = var.task_param.kafka_init.cpu
  kafka_init_memory              = var.task_param.kafka_init.memory
  kafka_init_env_kafka_bootstrap = aws_msk_cluster.kafka.bootstrap_brokers_sasl_iam
  kafka_init_env_topic           = var.kafka_topic # topic
}

# #################################
# IAM: Task Execution Role
# #################################
# assume role
resource "aws_iam_role" "kafka_init_execution_role" {
  name               = "${var.project}-${var.env}-execution-role-kafka-init"
  assume_role_policy = data.aws_iam_policy_document.assume_role_ecs.json
}

# policy attachment: exec role
resource "aws_iam_role_policy_attachment" "kafka_init_exec_role" {
  role       = aws_iam_role.kafka_init_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# #################################
# IAM: Task Role
# #################################
resource "aws_iam_role" "kafka_init_task_role" {
  name               = "${var.project}-${var.env}-task-role-kafka-init"
  assume_role_policy = data.aws_iam_policy_document.assume_role_ecs.json
}

# policy attachment: producer with msk
data "aws_iam_policy_document" "kafka_init" {

  # cluster
  statement {
    sid    = "ClusterConnectDescribe"
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

  # Manage topic
  statement {
    sid    = "CreateTopic"
    effect = "Allow"
    actions = [
      "kafka-cluster:CreateTopic",
      "kafka-cluster:DescribeTopic",
      "kafka-cluster:DescribeTopicDynamicConfiguration",
      "kafka-cluster:AlterTopic",
      "kafka-cluster:AlterTopicDynamicConfiguration",
      "kafka-cluster:WriteData",
    ]
    resources = [
      "arn:aws:kafka:${var.aws_region}:${data.aws_caller_identity.current.account_id}:topic/${aws_msk_cluster.kafka.cluster_name}/${aws_msk_cluster.kafka.cluster_uuid}/telemetry"
    ]
  }
}

resource "aws_iam_policy" "kafka_init" {
  name   = "${var.project}-${var.env}-topic-kafka-init"
  policy = data.aws_iam_policy_document.kafka_init.json
}

resource "aws_iam_role_policy_attachment" "kafka_init_task_role" {
  role       = aws_iam_role.kafka_init_task_role.name
  policy_arn = aws_iam_policy.kafka_init.arn
}


# ##############################
# Security Group
# ##############################
resource "aws_security_group" "kafka_init" {
  name        = "${var.project}-${var.env}-sg-kafka-init"
  description = "Security group kafka-init"
  vpc_id      = aws_vpc.main.id

  # Egress to vpc only
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    # cidr_blocks = [aws_vpc.main.cidr_block]
  }


  tags = {
    Name = "${var.project}-${var.env}-sg-kafka-init"
  }
}


resource "aws_security_group_rule" "kafka_init" {
  type                     = "ingress"
  security_group_id        = aws_security_group.kafka.id
  from_port                = 9098
  to_port                  = 9098
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.kafka_init.id
  description              = "Allow ECS Kafka init to reach MSK SASL/IAM"
}

# #################################
# CloudWatch: log group
# #################################
resource "aws_cloudwatch_log_group" "kafka_init" {
  name              = local.kafka_init_log_id
  retention_in_days = 7
  kms_key_id        = aws_kms_key.cloudwatch_log.arn

  tags = {
    Name = local.kafka_init_log_id
  }
}

# #################################
# ECS: Task Definition
# #################################
resource "aws_ecs_task_definition" "kafka_init" {
  family                   = "${var.project}-${var.env}-kafka-init"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = local.kafka_init_cpu
  memory                   = local.kafka_init_memory

  execution_role_arn = aws_iam_role.kafka_init_execution_role.arn
  task_role_arn      = aws_iam_role.kafka_init_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "kafka-init"
      image     = local.kafka_init_ecr
      essential = true

      environment = [
        { name = "BOOTSTRAP_SERVERS", value = local.kafka_init_env_kafka_bootstrap },
        { name = "TOPIC_NAME", value = local.kafka_init_env_topic },
        { name = "PARTITIONS", value = "3" },
        { name = "REPLICATION_FACTOR", value = "3" }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = local.kafka_init_log_id
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

