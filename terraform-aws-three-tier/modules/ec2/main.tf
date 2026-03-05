resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-ec2-sg"
  description = "Allow SSH and HTTP inbound traffic"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name      = "${var.project_name}-ec2-sg"
    ManagedBy = "Terraform"
  }
}

resource "aws_instance" "app" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  key_name               = "tom-terraform-key"

user_data = <<-EOF
  #!/bin/bash
  yum update -y
  amazon-linux-extras install nginx1 -y
  systemctl enable --now nginx
  echo "<h1>Hello from Terraform - three-tier!</h1>" > /usr/share/nginx/html/index.html
EOF

  tags = {
    Name      = "${var.project_name}-app"
    ManagedBy = "Terraform"
  }
}
