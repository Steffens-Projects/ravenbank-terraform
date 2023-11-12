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
  depends_on = [aws_security_group.ecs_sg]
}

# RDS Database
resource "aws_db_instance" "database" {
  snapshot_identifier           = var.rds_snapshot # MAKE SURE THIS IS UPDATED
  identifier                    = "terraform-rds-db"
  skip_final_snapshot           = true
  instance_class                = "db.t3.micro"
  db_subnet_group_name          = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids        = [aws_security_group.rds_sg.id]
}
