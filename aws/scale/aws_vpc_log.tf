# # aws_vpc_log.tf

# # ##############################
# # IAM: log group
# # ##############################
# resource "aws_iam_role" "vpc_flow_log" {
#   name               = "${var.project}-${var.env}-assume-role-vpc-flow-log"
#   assume_role_policy = data.aws_iam_policy_document.vpc_flow_log.json
# }

# # policy doc
# data "aws_iam_policy_document" "vpc_flow_log" {
#   statement {
#     effect = "Allow"

#     principals {
#       type        = "Service"
#       identifiers = ["vpc-flow-logs.amazonaws.com"]
#     }

#     actions = ["sts:AssumeRole"]
#   }
# }

# # bind log group policy
# resource "aws_iam_role_policy" "log_group" {
#   name   = "example"
#   role   = aws_iam_role.vpc_flow_log.id
#   policy = data.aws_iam_policy_document.log_group_ops.json
# }

# data "aws_iam_policy_document" "log_group_ops" {
#   statement {
#     effect = "Allow"

#     actions = [
#       "logs:CreateLogGroup",
#       "logs:CreateLogStream",
#       "logs:PutLogEvents",
#       "logs:DescribeLogGroups",
#       "logs:DescribeLogStreams",
#     ]

#     resources = [
#       aws_cloudwatch_log_group.vpc_flow_log.arn
#     ]
#   }
# }

# # ##############################
# # Flow log
# # ##############################
# resource "aws_cloudwatch_log_group" "vpc_flow_log" {
#   name       = "${var.project}-${var.env}-log-group-vpc-flow"
#   kms_key_id = aws_kms_key.cloudwatch_log.arn
# }

# resource "aws_flow_log" "vpc_flow_log" {
#   iam_role_arn    = aws_iam_role.vpc_flow_log.arn
#   log_destination = aws_cloudwatch_log_group.vpc_flow_log.arn
#   traffic_type    = "ALL"
#   vpc_id          = aws_vpc.main.id
# }
