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

# VPC par défaut
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# 1. Cluster ECS - VOUS AVIEZ OUBLIÉ "resource ... {"
resource "aws_ecs_cluster" "akaunting" {
  name = "akaunting-cluster-${var.environment}"

  setting {
    name  = "containerInsights"
    value = var.enable_monitoring ? "enabled" : "disabled"
  }
}

# 2. IAM Role - AJOUTEZ CETTE RESSOURCE MANQUANTE
resource "aws_iam_role" "ecs_execution" {
  name = "akaunting-ecs-role-${var.environment}"

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

# 3. Attachement de policy IAM
resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# 4. CloudWatch Log Group - AJOUTEZ CETTE RESSOURCE MANQUANTE
resource "aws_cloudwatch_log_group" "akaunting" {
  name              = "/ecs/akaunting-${var.environment}"
  retention_in_days = 30
}

# 5. Security Group
resource "aws_security_group" "akaunting" {
  name        = "akaunting-sg-${var.environment}"
  description = "Security group for Akaunting ECS"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "akaunting-sg-${var.environment}"
  }
}

# 6. Task Definition
resource "aws_ecs_task_definition" "akaunting" {
  family                   = "akaunting-task-${var.environment}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = aws_iam_role.ecs_execution.arn

  container_definitions = jsonencode([{
    name      = "akaunting"
    image     = "${var.docker_image}:${var.docker_image_tag}"
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
}

# 7. Service ECS
resource "aws_ecs_service" "akaunting" {
  name            = "akaunting-service-${var.environment}"
  cluster         = aws_ecs_cluster.akaunting.id
  task_definition = aws_ecs_task_definition.akaunting.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.akaunting.id]
    assign_public_ip = true
  }

  force_new_deployment = true
}
