# ---------------------------------------------------------------------------
# outputs.tf
# Values printed to the terminal after `terraform apply` completes.
# Use these to quickly find your instance without logging into the AWS console.
# ---------------------------------------------------------------------------

output "public_ip" {
  description = "The Elastic IP address of the web server. Use this in DNS A records."
  value       = aws_eip.web.public_ip
}

output "public_dns" {
  description = "The public DNS hostname of the EC2 instance. Useful for quick browser testing."
  value       = aws_instance.web.public_dns
}

output "instance_id" {
  description = "The EC2 instance ID. Use with AWS CLI: aws ec2 describe-instances --instance-ids <id>"
  value       = aws_instance.web.id
}

output "ssh_command" {
  description = "Ready-to-run SSH command. Requires an EC2 key pair — add key_name to the aws_instance resource first."
  value       = "ssh -i <your-key.pem> ec2-user@${aws_eip.web.public_ip}"
}
