output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_1_id" {
  description = "ID of public subnet in ca-central-1a"
  value       = aws_subnet.public_1.id
}

output "public_2_id" {
  description = "ID of public subnet in ca-central-1b"
  value       = aws_subnet.public_2.id
}

output "private_1_id" {
  description = "ID of private subnet in ca-central-1a"
  value       = aws_subnet.private_1.id
}

output "private_2_id" {
  description = "ID of private subnet in ca-central-1b"
  value       = aws_subnet.private_2.id
}
