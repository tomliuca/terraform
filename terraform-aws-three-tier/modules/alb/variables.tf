variable "project_name" {
  description = "Project name for resource naming and tagging"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "public_subnet_1" {
  description = "ID of the first public subnet"
  type        = string
}

variable "public_subnet_2" {
  description = "ID of the second public subnet"
  type        = string
}

variable "ec2_instance_id" {
  description = "ID of the EC2 instance to attach to the target group"
  type        = string
}
