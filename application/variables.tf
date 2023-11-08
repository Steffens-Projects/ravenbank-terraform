variable "vpc_id" { # Gathers the VPC
    description = "The VPC ID that the infrastructure should be deployed in."
    type = string
}

variable "rds_snapshot" {
    type = string
}

data "aws_vpc" "aws-vpc" {
  id = var.vpc_id
}

variable "hosted_zone" {
    description = "Hosted zone of your route53"
    type = string
}

variable "certificate_arn" {
    description = "SSL/TLS Certificate"
    type = string
}

data "aws_route53_zone" "hosted_zone_data" {
  name = var.hosted_zone
}

variable "region" {
    type = string
    description = "Region to deploy in AWS"
}

data "aws_subnets" "private_subnets" { # Gathers all subnets in the VPC
    filter {
        name   = "vpc-id"
        values = [data.aws_vpc.aws-vpc.id]
    }

    filter {
        name   = "tag:Tier"
        values = ["Private"]
    }
}

data "aws_subnets" "public_subnets" { # Gathers all subnets in the VPC
    filter {
        name   = "vpc-id"
        values = [data.aws_vpc.aws-vpc.id]
    }

    filter {
        name   = "tag:Tier"
        values = ["Public"]
    }
}

variable "ecs_task_role_arn" {
    default = "arn:aws:iam::230371373527:role/ECSFullAccess"
}

# Container definition for ECS task
locals {
  container_definition = <<DEFINITION
  [
    {
      "name": "ravenbank-container",
      "image": "steffenp123/raven-bank",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 80,
          "hostPort": 80,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "MYSQL_MASTER_PASSWORD",
          "value": "${local.rds_secret["MYSQL_MASTER_PASSWORD"]}"
        },
        {
          "name": "MYSQL_MASTER_USER",
          "value": "${local.rds_secret["MYSQL_MASTER_USER"]}"
        },
        {
          "name": "MYSQL_DATABASE",
          "value": "${local.rds_secret["MYSQL_DATABASE"]}"
        },
        {
          "name": "SECRET_KEY",
          "value": "${local.rds_secret["SECRET_KEY"]}"
        },
        {
          "name": "AWS_ACCESS_KEY_ID",
          "value": "${local.rds_secret["AWS_ACCESS_KEY_ID"]}"
        },
        {
          "name": "AWS_SECRET_ACCESS_KEY",
          "value": "${local.rds_secret["AWS_SECRET_ACCESS_KEY"]}"
        },
        {
          "name": "AWS_REGION_NAME",
          "value": "${local.rds_secret["AWS_REGION_NAME"]}"
        },
        {
          "name": "VERIFIED_SES_EMAIL",
          "value": "${local.rds_secret["VERIFIED_SES_EMAIL"]}"
        },
        {
          "name": "MYSQL_HOSTNAME",
          "value": "${aws_db_instance.database.address}"
        }
      ],
      "logConfiguration": { 
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/terraform-ecs-logs",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "ecs" ,
          "awslogs-create-group": "true"
        }
      },
      "ephemeralStorage": {
        "sizeInGiB": 20
      },
      "memory": 2048,
      "cpu": 512
    }
  ]
  DEFINITION
}

variable "rds_secret_name" {
    type = string
}

data "aws_secretsmanager_secret_version" "rds_secret_version" {
    secret_id = var.rds_secret_name
}

locals {
    rds_secret = jsondecode(data.aws_secretsmanager_secret_version.rds_secret_version.secret_string)
}