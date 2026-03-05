variable "project_name" {
  description = "Project name for resource naming and tagging"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for the EC2 instance"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "public_subnet_id" {
  description = "ID of the public subnet to place the EC2 instance in"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}
