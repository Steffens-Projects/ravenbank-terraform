resource "aws_db_subnet_group" "db_subnet_group" {
  name                          = "terraform-vpc-db-subnet-group"
  subnet_ids                    = data.aws_subnets.private_subnets.ids
}

# Security group for RDS Database
resource "aws_security_group" "rds_sg" {
  name                          = "Terraform RDS SG"
  description                   = "Allow ECS access to RDS MySQL DB"
  vpc_id                        = data.aws_vpc.aws-vpc.id
  ingress {
    from_port                   = 3306
    to_port                     = 3306
    protocol                    = "tcp"
    security_groups = [aws_security_group.ecs_sg.id]
  }
  egress {
    from_port                   = 0
    to_port                     = 0
    protocol                    = "-1"
    cidr_blocks                 = ["0.0.0.0/0"]
  }
}

# RDS Database
resource "aws_db_instance" "database" {
  snapshot_identifier           = var.rds_snapshot # MAKE SURE THIS IS UPDATED
  identifier                    = "terraform-rds-db"
  skip_final_snapshot           = true
  instance_class                = "db.t3.micro"
  db_subnet_group_name          = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids        = [aws_security_group.rds_sg.id]
  depends_on = [data.aws_vpc.aws-vpc]
}

# AWS ECS Cluster
resource "aws_ecs_cluster" "ecs_cluster" {
  name = "Terraform-ECS-Cluster"
  depends_on = [data.aws_vpc.aws-vpc]
}

# AWS ECS Task Definition
resource "aws_ecs_task_definition" "task_definition" {
  family = "Raven-Bank-Task-Definition"
  network_mode = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu = "512"
  memory = "2048"
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
  execution_role_arn = var.ecs_task_role_arn
  task_role_arn = var.ecs_task_role_arn
  container_definitions = local.container_definition
}

# ECS SECURITY GROUP
resource "aws_security_group" "ecs_sg" {
  name                          = "Terraform ECS SG"
  description                   = "Configure ECS access"
  vpc_id                        = data.aws_vpc.aws-vpc.id
  ingress {
    from_port                   = 80
    to_port                     = 80
    protocol                    = "tcp"
    security_groups = [aws_security_group.lb_security_group.id] 
  }
  egress {
    from_port                   = 0
    to_port                     = 0
    protocol                    = "-1"
    cidr_blocks                 = ["0.0.0.0/0"]
  }
}

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

# ECS SERVICE NEXT
resource "aws_ecs_service" "ecs_service" {
  name = "flaskapp-service"
  cluster = aws_ecs_cluster.ecs_cluster.id
  launch_type = "FARGATE"
  desired_count = 1
  task_definition = aws_ecs_task_definition.task_definition.arn
  network_configuration {
    subnets = data.aws_subnets.private_subnets.ids
    security_groups = [aws_security_group.ecs_sg.id]
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.target_group.arn
    container_name = "ravenbank-container"
    container_port = "80"
  }
}

# Create Route 53 record that points to ALB
resource "aws_route53_record" "route53_record" {
    zone_id = data.aws_route53_zone.hosted_zone_data.zone_id
    name = "ravenbank.${var.hosted_zone}"
    type = "A"
    alias {
    name                   = aws_lb.load_balancer.dns_name
    zone_id                = aws_lb.load_balancer.zone_id
    evaluate_target_health = false
  }
}

resource "aws_cloudwatch_log_group" "ecs_logs" {
  name = "/ecs/terraform-ecs-logs"
}
