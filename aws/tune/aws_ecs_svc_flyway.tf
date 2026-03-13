# aws_ecs_svc_flyway.tf

# #################################
# Variable
# #################################
locals {
  flyway_log_id        = "/ecs/task/${var.project}-${var.env}-flyway"
  flyway_ecr           = "${local.ecr_repo}:${var.task_param.flyway.image_suffix}"
  flyway_env_pgdb_host = aws_db_instance.postgres.address
  flyway_env_pgdb_db   = aws_db_instance.postgres.db_name
  flyway_env_pgdb_user = aws_db_instance.postgres.username
  flyway_env_pgdb_pwd  = aws_db_instance.postgres.password
  flyway_appuser_pwd   = var.db_app_pwd
  flyway_readonly_pwd  = var.db_readonly_pwd
}

# #################################
# IAM: Execution Role
# #################################
# assume role
resource "aws_iam_role" "ecs_task_execution_role_flyway" {
  name               = "${var.project}-${var.env}-execution-role-flyway"
  assume_role_policy = data.aws_iam_policy_document.assume_role_ecs.json
}

# policy attachment: exec role
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy_flyway" {
  role       = aws_iam_role.ecs_task_execution_role_flyway.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# #################################
# IAM: Task Role
# #################################
resource "aws_iam_role" "ecs_task_role_flyway" {
  name               = "${var.project}-${var.env}-task-role-flyway"
  assume_role_policy = data.aws_iam_policy_document.assume_role_ecs.json
}

# ##############################
# Security Group
# ##############################
resource "aws_security_group" "flyway" {
  name        = "${var.project}-${var.env}-sg-flyway"
  description = "Security group flyway"
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
    Name = "${var.project}-${var.env}-sg-flyway"
  }
}

# #################################
# ECS: Task Definition
# #################################
resource "aws_ecs_task_definition" "flyway" {
  family                   = "${var.project}-${var.env}-task-flyway"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role_flyway.arn
  task_role_arn            = aws_iam_role.ecs_task_role_flyway.arn

  container_definitions = templatefile("${path.module}/container/flyway.tftpl", {
    image                 = local.flyway_ecr
    awslogs_group         = local.flyway_log_id
    region                = var.aws_region
    pghost                = local.flyway_env_pgdb_host
    pgport                = 5432
    pgdatabase            = local.flyway_env_pgdb_db
    pguser                = local.flyway_env_pgdb_user
    pgpwd                 = local.flyway_env_pgdb_pwd
    app_user_password     = local.flyway_appuser_pwd
    app_readonly_password = local.flyway_readonly_pwd
  })

  tags = {
    Name = "${var.project}-${var.env}-task-db-init"
  }

  depends_on = [
    aws_db_instance.postgres,
    aws_cloudwatch_log_group.flyway,
  ]
}

resource "aws_cloudwatch_log_group" "flyway" {
  name              = local.flyway_log_id
  retention_in_days = 7

  kms_key_id = aws_kms_key.cloudwatch_log.arn

  tags = {
    Name = local.flyway_log_id
  }
}
