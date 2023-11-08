module "aws-vpc" {
  source         = "terraform-aws-modules/vpc/aws"
  name           = "terraform-vpc"
  cidr           = "192.168.0.0/16"
  azs            = ["us-east-1a", "us-east-1b"]
  public_subnets = ["192.168.1.0/24", "192.168.2.0/24"]
  public_subnet_tags = {
    "Tier" = "Public"
  }

  private_subnet_tags = {
    "Tier" = "Private"
  }
  private_subnets    = ["192.168.3.0/24", "192.168.4.0/24"]
  enable_nat_gateway = true
  single_nat_gateway = true 
}

module "application" {
  source          = "../application"                                                             
  vpc_id          = module.aws-vpc.vpc_id                                                                 
  hosted_zone     = "steffenaws.net"                                                                      
  certificate_arn = "arn:aws:acm:us-east-1:230371373527:certificate/2b2354bb-fe3f-415f-adb3-c163de7af49c" 
  region          = "us-east-1"                                                                           
  rds_snapshot    = "arn:aws:rds:us-east-1:230371373527:snapshot:ravenbank-database-snapshot"              
  rds_secret_name = "terraform/rds/secret"                                                                
}


# CREATE NEW RDS SNAPSHOT, CHATGPT HAS INFO