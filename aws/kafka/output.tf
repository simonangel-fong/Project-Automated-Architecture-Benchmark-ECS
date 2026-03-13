output "dns_url" {
  value = "https://${cloudflare_record.dns_record.hostname}"
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.ecs_cluster.name
}

output "flyway_init_cmd" {
  value = <<EOF
  aws ecs run-task  \
    --launch-type FARGATE \
    --region "${var.aws_region}" \
    --cluster "${aws_ecs_cluster.ecs_cluster.name}" \
    --task-definition "${aws_ecs_task_definition.flyway.arn}" \
    --network-configuration "awsvpcConfiguration={subnets=[${join(",", [for s in aws_subnet.private : s.id])}],securityGroups=[${aws_security_group.flyway.id}]}" \
    --output json

EOF
}


output "kafka_init_cmd" {
  value = <<EOF

  aws ecs run-task    \
    --launch-type "FARGATE"   \
    --region "${var.aws_region}"    \
    --cluster ${aws_ecs_cluster.ecs_cluster.name}   \
    --task-definition ${aws_ecs_task_definition.kafka_init.arn}   \
    --network-configuration "awsvpcConfiguration={subnets=[${join(",", [for s in aws_subnet.private : s.id])}],securityGroups=[${aws_security_group.kafka_init.id}]}"   \
    --output json
    
EOF
}
