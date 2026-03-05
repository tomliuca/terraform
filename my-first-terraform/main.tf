# 告诉 Terraform 用 AWS provider
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ca-central-1"
}

# 创建一台 EC2
resource "aws_instance" "my_server" {
  ami           = "ami-093fa3bd802d96b73"  # Amazon Linux 2
  instance_type = "t3.micro"               # 免费套餐

  tags = {
    Name        = "Tom-First-Server"
    Environment = "learning"
  }
}
