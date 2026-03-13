# ###########################################
# aws_elasticache_logging.tf
# a file to define redis logging
# ###########################################

# #################################
# CloudWatch: log group
# #################################
resource "aws_cloudwatch_log_group" "redis" {
  name              = local.redis_logging_name
  retention_in_days = 7
  kms_key_id        = aws_kms_key.cloudwatch_log.arn

  tags = {
    Name = local.redis_logging_name
  }
}
