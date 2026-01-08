# Load Balancer
resource "aws_lb" "akaunting" {
  name               = "akaunting-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  tags = {
    Name        = "akaunting-lb"
    Environment = var.environment
  }
}

# Target Group
resource "aws_lb_target_group" "akaunting" {
  name        = "akaunting-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    interval            = 30
    path                = "/"
    port                = "traffic-port"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    matcher             = "200-299"
  }

  tags = {
    Name        = "akaunting-tg"
    Environment = var.environment
  }
}

# Listener
resource "aws_lb_listener" "akaunting" {
  load_balancer_arn = aws_lb.akaunting.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.akaunting.arn
  }

  tags = {
    Name        = "akaunting-listener"
    Environment = var.environment
  }
}
