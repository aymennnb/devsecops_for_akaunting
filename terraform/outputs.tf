output "ecs_cluster_name" {
  description = "ECS Cluster Name"
  value       = aws_ecs_cluster.akaunting.name
}

output "ecs_service_name" {
  description = "ECS Service Name"
  value       = aws_ecs_service.akaunting.name
}

output "load_balancer_dns" {
  description = "Load Balancer DNS Name"
  value       = aws_lb.akaunting.dns_name
}

output "docker_image" {
  description = "Docker image deployed"
  value       = var.docker_image
}
