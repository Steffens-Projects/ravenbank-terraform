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
  depends_on = [aws_security_group.lb_security_group]
}

# Log group for ECS
resource "aws_cloudwatch_log_group" "ecs_logs" {
  name = "/ecs/terraform-ecs-logs"
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
  depends_on = [aws_lb_target_group.target_group]
}