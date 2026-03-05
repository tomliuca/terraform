# ---------------------------------------------------------------------------
# variables.tf
# All configurable inputs for this module. Override via terraform.tfvars or
# -var flags. Sensible defaults are provided so `terraform apply` works
# out of the box for evaluation purposes.
# ---------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region to deploy all resources into."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Short name used as a prefix on all resource Name tags. Helps identify resources in the AWS console."
  type        = string
  default     = "web-server"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC. /16 gives 65,536 addresses — plenty of room to add more subnets later."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet. Must be a subset of vpc_cidr."
  type        = string
  default     = "10.0.1.0/24"
}

variable "availability_zone" {
  description = "AZ for the public subnet. Single-AZ is fine for a demo; add more subnets across AZs for HA."
  type        = string
  default     = "us-east-1a"
}

variable "instance_type" {
  description = "EC2 instance type. t3.micro is free-tier eligible and sufficient for a basic web server."
  type        = string
  default     = "t3.micro"
}

variable "allowed_ssh_cidr" {
  description = <<-EOT
    CIDR block allowed to reach port 22 (SSH).
    Default 0.0.0.0/0 is intentionally open for quick evaluation — RESTRICT THIS
    to your own IP (e.g. "203.0.113.5/32") before running in any real environment.
  EOT
  type        = string
  default     = "0.0.0.0/0"
}
