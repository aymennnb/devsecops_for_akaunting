provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Project     = "Akaunting"
    }
  }
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# resource "aws_ecs_cluster" "akaunting" {
  name = "akaunting-cluster-${var.environment}"

  setting {
    name  = "containerInsights"
    value = var.enable_monitoring ? "enabled" : "disabled"
  }

  lifecycle {
    prevent_destroy = true  # Empêche la destruction accidentelle
  }
}

# Security Group avec règles dynamiques
resource "aws_security_group" "akaunting" {
  name        = "akaunting-sg-${var.environment}"
  description = "Security group for Akaunting ECS"
  vpc_id      = data.aws_vpc.default.id

  dynamic "ingress" {
    for_each = var.environment == "production" ? [1] : []
    content {
      description = "HTTP from anywhere"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "akaunting-sg-${var.environment}"
  }
}

# Task Definition qui change seulement si l'image change
resource "aws_ecs_task_definition" "akaunting" {
  family                   = "akaunting-task-${var.environment}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = aws_iam_role.ecs_execution.arn

  container_definitions = jsonencode([{
    name      = "akaunting"
    image     = "aymen138/akaunting_devops_project:${var.docker_image_tag}"
    cpu       = 1024
    memory    = 2048
    essential = true
    portMappings = [{
      containerPort = 80
      hostPort      = 80
      protocol      = "tcp"
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.akaunting.name
        awslogs-region        = "us-east-1"
        awslogs-stream-prefix = "ecs"
      }
    }
  }])

  # Force une nouvelle révision seulement si l'image change
  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      # Ignore les changements de tags qui ne sont pas critiques
      tags_all
    ]
  }
}

# Service ECS avec stratégie de déploiement
resource "aws_ecs_service" "akaunting" {
  name            = "akaunting-service-${var.environment}"
  cluster         = aws_ecs_cluster.akaunting.id
  task_definition = aws_ecs_task_definition.akaunting.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  deployment_controller {
    type = "ECS"
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.akaunting.id]
    assign_public_ip = true
  }

  # Permet un déploiement progressif
  ordered_placement_strategy {
    type  = "spread"
    field = "attribute:ecs.availability-zone"
  }

  lifecycle {
    ignore_changes = [
      desired_count,  # Peut être géré par Auto Scaling
      task_definition  # Géré par la force_new_deployment
    ]
  }
}
