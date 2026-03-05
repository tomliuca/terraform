output "endpoint" {
  description = "Connection endpoint of the RDS instance"
  value       = aws_db_instance.mysql.endpoint
}

output "db_name" {
  description = "Name of the database"
  value       = aws_db_instance.mysql.db_name
}
