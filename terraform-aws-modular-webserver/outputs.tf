output "server_public_ip" {
  description = "Public IP address of the web server"
  value       = module.ec2.public_ip
}

output "server_url" {
  description = "HTTP URL of the web server"
  value       = "http://${module.ec2.public_ip}"
}

output "vpc_id" {
  description = "ID of the created VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = module.vpc.public_subnet_id
}
