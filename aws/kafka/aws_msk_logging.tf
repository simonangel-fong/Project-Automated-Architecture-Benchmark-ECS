# ###########################################
# aws_msk_logging.tf
# a file to define Kafka (MSK) CloudWatch logging
# ###########################################

# #################################
# CloudWatch: log group
# #################################
resource "aws_cloudwatch_log_group" "kafka" {
  name              = local.msk_log_name
  retention_in_days = 7
  kms_key_id        = aws_kms_key.cloudwatch_log.arn

  tags = {
    Name = local.msk_log_name
  }
}
