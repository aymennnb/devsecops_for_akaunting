output "ecs_cluster_name" {
  value       = aws_ecs_cluster.akaunting.name
  description = "Nom du cluster ECS"
}

output "ecs_service_name" {
  value       = aws_ecs_service.akaunting.name
  description = "Nom du service ECS"
}

output "task_definition_revision" {
  value       = aws_ecs_task_definition.akaunting.revision
  description = "Révision de la task definition"
}

output "security_group_id" {
  value       = aws_security_group.akaunting.id
  description = "ID du Security Group"
}
