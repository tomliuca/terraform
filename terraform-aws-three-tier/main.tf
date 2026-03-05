terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "tom-terraform-state-2024"
    key            = "dev/three-tier.tfstate"
    region         = "ca-central-1"
    dynamodb_table = "terraform-state-lock"
  }
}

provider "aws" {
  region = var.aws_region
}

module "vpc" {
  source = "./modules/vpc"

  project_name = var.project_name
  vpc_cidr     = var.vpc_cidr
}

module "ec2" {
  source = "./modules/ec2"

  project_name      = var.project_name
  ami_id            = var.ami_id
  instance_type     = var.instance_type
  public_subnet_id  = module.vpc.public_1_id
  vpc_id            = module.vpc.vpc_id
}

module "rds" {
  source = "./modules/rds"

  project_name       = var.project_name
  db_name            = var.db_name
  db_username        = var.db_username
  db_password        = var.db_password
  private_subnet_1   = module.vpc.private_1_id
  private_subnet_2   = module.vpc.private_2_id
  ec2_security_group = module.ec2.security_group_id
  vpc_id             = module.vpc.vpc_id
}

module "alb" {
  source = "./modules/alb"

  project_name      = var.project_name
  vpc_id            = module.vpc.vpc_id
  public_subnet_1   = module.vpc.public_1_id
  public_subnet_2   = module.vpc.public_2_id
  ec2_instance_id   = module.ec2.instance_id
}
