# #################################
# aws_rds_monitoring.tf
# a file to define monitoring
# #################################

# ##############################
# Monitoring: IAM
# ##############################
resource "aws_iam_role" "rds_assume_role" {
  name = "${var.project}-${var.env}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# rds monitoring policy
resource "aws_iam_role_policy_attachment" "rds_monitoring_policy" {
  role       = aws_iam_role.rds_assume_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# ##############################
# Monitoring: cup alarm
# ##############################
resource "aws_cloudwatch_metric_alarm" "rds_high_cpu" {
  alarm_name          = "${var.project}-${var.env}-rds-high-cpu"
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  comparison_operator = "GreaterThanThreshold"
  statistic           = "Average"
  threshold           = 80
  period              = 60 # period in seconds
  evaluation_periods  = 2  # number of periods to compare with threshold 

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.postgres.id
  }

  alarm_description = "RDS Postgres CPU > 80% for 2 minutes"
}

# ##############################
# Monitoring: memory alarm
# ##############################
resource "aws_cloudwatch_metric_alarm" "rds_low_memory" {
  alarm_name          = "${var.project}-${var.env}-rds-low-memory"
  namespace           = "AWS/RDS"
  metric_name         = "FreeableMemory"
  comparison_operator = "LessThanThreshold"
  statistic           = "Average"
  threshold           = 200 * 1024 * 1024 # 200 MiB in bytes
  period              = 60                # period in seconds
  evaluation_periods  = 2                 # number of periods to compare with threshold 

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.postgres.id
  }

  alarm_description = "RDS Postgres freeable memory < 200MiB for 2 minutes"
}

# ##############################
# Monitoring: storage alarm
# ##############################
resource "aws_cloudwatch_metric_alarm" "rds_low_storage" {
  alarm_name          = "${var.project}-${var.env}-rds-low-storage"
  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  comparison_operator = "LessThanThreshold"
  statistic           = "Average"
  threshold           = 5 * 1024 * 1024 * 1024 # 5 GiB in bytes
  period              = 300                    # period in seconds
  evaluation_periods  = 2                      # number of periods to compare with threshold.  

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.postgres.id
  }

  alarm_description = "RDS Postgres free storage < 5GiB"
}
