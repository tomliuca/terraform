output "alb_url" {
  description = "DNS name of the Application Load Balancer"
  value       = "http://${module.alb.dns_name}"
}

output "rds_endpoint" {
  description = "Endpoint of the RDS MySQL instance"
  value       = module.rds.endpoint
}
output "ec2_public_ip" {
  value = module.ec2.public_ip
}
