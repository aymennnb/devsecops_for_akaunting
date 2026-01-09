terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Utilise le VPC par défaut AWS
data "aws_vpc" "default" {
  default = true
}

# Sélectionne uniquement les subnets publics
data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "map-public-ip-on-launch"
    values = ["true"]
  }
}

# Cluster ECS
resource "aws_ecs_cluster" "akaunting" {
  name = "akaunting-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# Security Group
resource "aws_security_group" "akaunting" {
  name        = "akaunting-sg"
  description = "Allow HTTP traffic"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# IAM Role pour ECS
resource "aws_iam_role" "ecs_execution" {
  name = "akaunting-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

# Attache la policy
resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Task Definition
resource "aws_ecs_task_definition" "akaunting" {
  family                   = "akaunting-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = aws_iam_role.ecs_execution.arn

  container_definitions = jsonencode([{
    name      = "akaunting"
    image     = "${var.docker_image}:${var.image_tag}"
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
        awslogs-group         = "/ecs/akaunting"
        awslogs-region        = "us-east-1"
        awslogs-stream-prefix = "ecs"
      }
    }
  }])
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "akaunting" {
  name              = "/ecs/akaunting"
  retention_in_days = 30
}

# Service ECS
resource "aws_ecs_service" "akaunting" {
  name            = "akaunting-service"
  cluster         = aws_ecs_cluster.akaunting.id
  task_definition = aws_ecs_task_definition.akaunting.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.public.ids
    security_groups  = [aws_security_group.akaunting.id]
    assign_public_ip = true
  }

  # Permet à Terraform de gérer les changements de la task definition
  force_new_deployment = true

  # Attendre que le service soit stable
  wait_for_steady_state = false

  depends_on = [
    aws_iam_role_policy_attachment.ecs_execution,
    aws_cloudwatch_log_group.akaunting
  ]
}

# Variables
variable "docker_image" {
  description = "Docker image name"
  default     = "aymen138/akaunting_devops_project"
}

variable "image_tag" {
  description = "Docker image tag"
  default     = "latest"
}

# Outputs
output "ecs_cluster_name" {
  value = aws_ecs_cluster.akaunting.name
}

output "ecs_service_name" {
  value = aws_ecs_service.akaunting.name
}

output "task_definition_arn" {
  value = aws_ecs_task_definition.akaunting.arn
}
