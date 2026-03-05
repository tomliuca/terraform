variable "project_name" {
  description = "Project name for resource naming and tagging"
  type        = string
}

variable "db_name" {
  description = "Name of the initial database"
  type        = string
}

variable "db_username" {
  description = "Master username for the RDS instance"
  type        = string
}

variable "db_password" {
  description = "Master password for the RDS instance"
  type        = string
  sensitive   = true
}

variable "private_subnet_1" {
  description = "ID of the first private subnet"
  type        = string
}

variable "private_subnet_2" {
  description = "ID of the second private subnet"
  type        = string
}

variable "ec2_security_group" {
  description = "Security group ID of the EC2 instance (allowed to reach RDS)"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}
