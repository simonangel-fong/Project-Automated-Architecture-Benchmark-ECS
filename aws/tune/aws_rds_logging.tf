# # #################################
# # aws_rds_log.tf
# # a file to define logging
# # #################################

# # #################################
# # Variable
# # #################################
# locals {
#   rds_postgres_log_group_name = "/aws/rds/instance/${local.rds_postgres_identifier}/postgresql"
# }

# # ##############################
# # Log Group
# # ##############################
# resource "aws_cloudwatch_log_group" "rds_postgres" {
#   name              = local.rds_postgres_log_group_name
#   retention_in_days = 7

#   # optional: encryption
#   kms_key_id = aws_kms_key.cloudwatch_log.arn

#   tags = {
#     Name = "${var.project}-${var.env}-rds-postgres-logs"
#   }
# }
