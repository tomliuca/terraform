# ---------------------------------------------------------------------------
# main.tf
# Provisions the complete AWS web server stack in dependency order:
#   VPC → Subnet → IGW → Route Table → Security Group → EC2 → Elastic IP
#
# Every resource has a comment explaining WHY it exists and how it connects
# to its neighbors. Read top-to-bottom for a guided tour of the architecture.
# ---------------------------------------------------------------------------

terraform {
  required_version = ">= 1.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS provider with the region from variables.
# Credentials are read from the environment (AWS_ACCESS_KEY_ID /
# AWS_SECRET_ACCESS_KEY) or the ~/.aws/credentials file — never hardcoded here.
provider "aws" {
  region = var.aws_region
}

# ---------------------------------------------------------------------------
# VPC
# A Virtual Private Cloud is our isolated network boundary inside AWS.
# Without a VPC, we cannot place any compute or networking resources.
# enable_dns_hostnames = true is required so EC2 instances receive a
# public DNS name (e.g. ec2-x-x-x-x.compute-1.amazonaws.com).
# ---------------------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# ---------------------------------------------------------------------------
# Public Subnet
# A subnet carves a slice of the VPC's IP space into a specific AZ.
# map_public_ip_on_launch = true means any EC2 launched here automatically
# gets a public IP — this is what makes it a "public" subnet.
# ---------------------------------------------------------------------------
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet"
  }
}

# ---------------------------------------------------------------------------
# Internet Gateway (IGW)
# The IGW is the door between our VPC and the public internet.
# Without it, no traffic can flow in or out, even if instances have public IPs.
# One IGW per VPC is the standard pattern.
# ---------------------------------------------------------------------------
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# ---------------------------------------------------------------------------
# Route Table
# A route table tells subnets where to send traffic.
# The route 0.0.0.0/0 → IGW means "send all internet-bound traffic through
# the internet gateway". Without this route, outbound internet access is blocked.
# ---------------------------------------------------------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# ---------------------------------------------------------------------------
# Route Table Association
# Links the route table to the public subnet.
# A subnet without an explicit association uses the VPC's default route table,
# which has no internet route. This association makes the subnet truly public.
# ---------------------------------------------------------------------------
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ---------------------------------------------------------------------------
# Security Group
# Acts as a stateful firewall for the EC2 instance.
# Ingress rules: allow HTTP (80), HTTPS (443) from anywhere, SSH (22) from
#                the allowed_ssh_cidr variable (restrict to your IP in production).
# Egress rule:   allow all outbound traffic so the instance can reach the
#                internet (e.g. to run dnf update in user_data).
# ---------------------------------------------------------------------------
resource "aws_security_group" "web" {
  name        = "${var.project_name}-sg"
  description = "Allow HTTP, HTTPS, and SSH inbound; all outbound"
  vpc_id      = aws_vpc.main.id

  # HTTP — required for Nginx to serve web traffic on the standard port
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS — required if you add TLS termination (e.g. Certbot) later
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH — restrict allowed_ssh_cidr to your IP ("x.x.x.x/32") in production
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  # Allow all outbound so the instance can reach package repos, etc.
  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-sg"
  }
}

# ---------------------------------------------------------------------------
# AMI Data Source
# Looks up the latest Amazon Linux 2023 AMI ID at apply time so the config
# never goes stale. Amazon Linux 2023 is the modern successor to AL2 — it uses
# dnf, ships with newer packages, and is supported until 2028.
# ---------------------------------------------------------------------------
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ---------------------------------------------------------------------------
# EC2 Instance
# The virtual machine that will run Nginx.
# user_data runs userdata.sh at first boot via cloud-init — it installs and
# starts Nginx without any manual SSH required.
# The instance is placed in the public subnet so it gets a public IP.
# ---------------------------------------------------------------------------
resource "aws_instance" "web" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web.id]

  # Read the bootstrap script and pass it to cloud-init.
  # filebase64 base64-encodes the file, which is what the EC2 API expects.
  user_data = filebase64("${path.module}/userdata.sh")

  # Terminate the root volume when the instance is destroyed — prevents
  # orphaned EBS volumes accumulating on your account.
  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = true

    tags = {
      Name = "${var.project_name}-root-volume"
    }
  }

  tags = {
    Name = "${var.project_name}-ec2"
  }
}

# ---------------------------------------------------------------------------
# Elastic IP
# A static public IPv4 address that persists across EC2 stop/start cycles.
# Without an EIP, AWS assigns a new ephemeral public IP every time the
# instance starts, which breaks DNS records and bookmarked URLs.
# domain = "vpc" is required for EIPs used inside a VPC.
# ---------------------------------------------------------------------------
resource "aws_eip" "web" {
  instance = aws_instance.web.id
  domain   = "vpc"

  # The EIP depends on the IGW existing first — AWS requirement for VPC EIPs
  depends_on = [aws_internet_gateway.main]

  tags = {
    Name = "${var.project_name}-eip"
  }
}
