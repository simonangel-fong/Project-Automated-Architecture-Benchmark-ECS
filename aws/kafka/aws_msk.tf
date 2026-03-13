# ###########################################
# aws_msk.tf
# a file to define Kafka service
# ###########################################

locals {
  msk_name          = "${var.project}-${var.env}-msk"
  msk_log_name      = "${var.project}-${var.env}-log-group-msk"
  msk_sg_name       = "${var.project}-${var.env}-sg-kafka"
  msk_instance_type = var.kafka_instance_type
  msk_volume_size   = var.kafka_volume_size
  msk_broker_count  = var.kafka_broker_count
  msk_kafka_version = "3.8.x"
}

# ##############################
# Security Group
# ##############################
resource "aws_security_group" "kafka" {
  name        = local.msk_sg_name
  description = "Kafka security group"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = local.msk_sg_name
  }
}

resource "aws_security_group_rule" "fastapi_to_msk" {
  type                     = "ingress"
  security_group_id        = aws_security_group.kafka.id
  from_port                = 9098
  to_port                  = 9098
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.fastapi.id
  description              = "Allow FastAPI ECS tasks to reach MSK SASL/IAM"
}

resource "aws_security_group_rule" "consumer_to_msk" {
  type                     = "ingress"
  security_group_id        = aws_security_group.kafka.id
  from_port                = 9098
  to_port                  = 9098
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.consumer.id
  description              = "Allow Consumer ECS tasks to reach MSK SASL/IAM"
}

# ##############################
# MSK Configuration
# ##############################
resource "aws_msk_configuration" "kafka" {
  name           = "${var.project}-${var.env}-msk-config"
  kafka_versions = [local.msk_kafka_version]

  server_properties = <<-EOF
num.partitions=3
group.initial.rebalance.delay.ms=0

default.replication.factor=3
min.insync.replicas=2
offsets.topic.replication.factor=3
transaction.state.log.replication.factor=3
transaction.state.log.min.isr=2
EOF

}

# ##############################
# MSK Cluster: Kafka
# ##############################
resource "aws_msk_cluster" "kafka" {
  cluster_name           = local.msk_name
  kafka_version          = local.msk_kafka_version
  number_of_broker_nodes = local.msk_broker_count

  # msk conf
  configuration_info {
    arn      = aws_msk_configuration.kafka.arn
    revision = aws_msk_configuration.kafka.latest_revision
  }

  broker_node_group_info {
    # instance
    instance_type = local.msk_instance_type

    # storage
    storage_info {
      ebs_storage_info {
        volume_size = local.msk_volume_size
      }
    }

    # network
    client_subnets  = [for s in aws_subnet.private : s.id]
    security_groups = [aws_security_group.kafka.id]
  }

  encryption_info {
    encryption_in_transit {
      client_broker = "TLS"
      # client_broker = "PLAINTEXT"
      in_cluster = true
    }
  }

  client_authentication {
    sasl {
      iam = true
    }
  }

  logging_info {
    broker_logs {
      cloudwatch_logs {
        enabled   = true
        log_group = aws_cloudwatch_log_group.kafka.name
      }
    }
  }

  tags = {
    Name = local.msk_name
  }
}
