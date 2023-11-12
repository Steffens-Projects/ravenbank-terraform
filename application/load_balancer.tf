# Security group for ECS' Load Balancer
resource "aws_security_group" "lb_security_group" {
    name        = "terraform-lb-security-group"
    vpc_id      = var.vpc_id
  ingress {
    from_port   = 443
    to_port     = 443
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

# Target group for ECS' Load Balancer
resource "aws_lb_target_group" "target_group" {
    name =      "terraform-target-group"
    port =      80
    protocol =  "HTTP"
    target_type = "ip"
    vpc_id =    var.vpc_id
    health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200-299"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }
}

# Load Balancer for AWS ECS Service
resource "aws_lb" "load_balancer" {
  name = "terraform-lb-ecs"
  internal = false
  load_balancer_type = "application"
  security_groups = [aws_security_group.lb_security_group.id]
  subnets = data.aws_subnets.public_subnets.ids
}

# Create HTTPS listener for load balancer
resource "aws_lb_listener" "lb_listener" {
    load_balancer_arn = aws_lb.load_balancer.arn
    port              = "443"
    protocol          = "HTTPS"
    ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
    certificate_arn   = var.certificate_arn
    default_action {
        type             = "forward"
        target_group_arn = aws_lb_target_group.target_group.arn
    }
}