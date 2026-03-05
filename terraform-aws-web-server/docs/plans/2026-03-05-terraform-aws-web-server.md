# terraform-aws-web-server Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create a production-quality, well-commented Terraform repo that provisions a complete AWS web server (VPC → Subnet → IGW → Route Table → Security Group → EC2 + EIP) with Nginx installed via user_data.

**Architecture:** Flat single-module Terraform structure. All resources in `main.tf`, inputs in `variables.tf`, outputs in `outputs.tf`. Nginx is installed at EC2 launch time via a `userdata.sh` script using Amazon Linux 2023's `dnf` package manager. An Elastic IP ensures the public address survives stop/start cycles.

**Tech Stack:** Terraform >= 1.3, AWS Provider ~> 5.0, Amazon Linux 2023, Nginx

---

### Task 1: Repo scaffold — git init + .gitignore

**Files:**
- Create: `/Users/hangchengliu/Documents/GitHub/terraform-aws-web-server/.gitignore`

**Step 1: Initialize git repo**

```bash
cd /Users/hangchengliu/Documents/GitHub/terraform-aws-web-server
git init
```

Expected: `Initialized empty Git repository in .../terraform-aws-web-server/.git/`

**Step 2: Create .gitignore**

```
# Terraform state — never commit, contains sensitive resource IDs and secrets
*.tfstate
*.tfstate.*
*.tfstate.backup

# Terraform variable files — may contain AWS credentials or IPs
*.tfvars
!terraform.tfvars.example

# Terraform working directory
.terraform/
.terraform.lock.hcl

# Crash logs
crash.log
crash.*.log

# Override files
override.tf
override.tf.json
*_override.tf
*_override.tf.json

# macOS
.DS_Store
```

**Step 3: Commit**

```bash
cd /Users/hangchengliu/Documents/GitHub/terraform-aws-web-server
git add .gitignore docs/
git commit -m "chore: initial repo scaffold with .gitignore and design doc"
```

---

### Task 2: variables.tf — all input variables

**Files:**
- Create: `/Users/hangchengliu/Documents/GitHub/terraform-aws-web-server/variables.tf`

**Step 1: Write variables.tf**

```hcl
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
```

**Step 2: Validate syntax**

```bash
cd /Users/hangchengliu/Documents/GitHub/terraform-aws-web-server
terraform init -backend=false 2>/dev/null || true
terraform validate
```

Expected: `Success! The configuration is valid.` (or "No configuration files" until more files exist — that's fine at this stage)

**Step 3: Commit**

```bash
git add variables.tf
git commit -m "feat: add input variables"
```

---

### Task 3: userdata.sh — Nginx bootstrap script

**Files:**
- Create: `/Users/hangchengliu/Documents/GitHub/terraform-aws-web-server/userdata.sh`

**Step 1: Write userdata.sh**

```bash
#!/bin/bash
# ---------------------------------------------------------------------------
# userdata.sh
# This script runs as root on the EC2 instance at first boot via cloud-init.
# It installs Nginx and configures it to start automatically on every reboot.
# Amazon Linux 2023 uses 'dnf' (not yum) as its package manager.
# ---------------------------------------------------------------------------

# Update all installed packages to pick up the latest security patches
dnf update -y

# Install Nginx from the Amazon Linux 2023 package repository
dnf install -y nginx

# Enable Nginx so it starts automatically after a reboot
systemctl enable nginx

# Start Nginx immediately — after this, port 80 should serve the default page
systemctl start nginx
```

**Step 2: Make it executable**

```bash
chmod +x /Users/hangchengliu/Documents/GitHub/terraform-aws-web-server/userdata.sh
```

**Step 3: Commit**

```bash
git add userdata.sh
git commit -m "feat: add Nginx user_data bootstrap script"
```

---

### Task 4: main.tf — all AWS resources

**Files:**
- Create: `/Users/hangchengliu/Documents/GitHub/terraform-aws-web-server/main.tf`

**Step 1: Write main.tf**

```hcl
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
```

**Step 2: Validate**

```bash
cd /Users/hangchengliu/Documents/GitHub/terraform-aws-web-server
terraform init
terraform validate
```

Expected: `Success! The configuration is valid.`

**Step 3: Commit**

```bash
git add main.tf
git commit -m "feat: add all AWS resources (VPC, subnet, IGW, SG, EC2, EIP)"
```

---

### Task 5: outputs.tf — useful values after apply

**Files:**
- Create: `/Users/hangchengliu/Documents/GitHub/terraform-aws-web-server/outputs.tf`

**Step 1: Write outputs.tf**

```hcl
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
```

**Step 2: Validate**

```bash
terraform validate
```

Expected: `Success! The configuration is valid.`

**Step 3: Commit**

```bash
git add outputs.tf
git commit -m "feat: add outputs (public_ip, public_dns, instance_id, ssh_command)"
```

---

### Task 6: terraform.tfvars.example — safe example config

**Files:**
- Create: `/Users/hangchengliu/Documents/GitHub/terraform-aws-web-server/terraform.tfvars.example`

**Step 1: Write terraform.tfvars.example**

```hcl
# ---------------------------------------------------------------------------
# terraform.tfvars.example
# Copy this file to terraform.tfvars and fill in your values.
#
#   cp terraform.tfvars.example terraform.tfvars
#
# terraform.tfvars is gitignored — safe to put real values there.
# This example file IS committed — never put real secrets here.
# ---------------------------------------------------------------------------

aws_region         = "us-east-1"
project_name       = "web-server"
vpc_cidr           = "10.0.0.0/16"
public_subnet_cidr = "10.0.1.0/24"
availability_zone  = "us-east-1a"
instance_type      = "t3.micro"

# IMPORTANT: Replace with your own IP to restrict SSH access.
# Find your IP: curl https://checkip.amazonaws.com
# Format: "x.x.x.x/32"
allowed_ssh_cidr = "0.0.0.0/0"
```

**Step 2: Commit**

```bash
git add terraform.tfvars.example
git commit -m "docs: add terraform.tfvars.example with safe placeholder values"
```

---

### Task 7: README.md

**Files:**
- Create: `/Users/hangchengliu/Documents/GitHub/terraform-aws-web-server/README.md`

**Step 1: Write README.md**

```markdown
# terraform-aws-web-server

实战项目 — 用 Terraform 搭建完整的 AWS Web 服务器

完整基础设施链：**VPC → 子网 → IGW → 路由表 → 安全组 → EC2 → Elastic IP**

EC2 启动时通过 `user_data` 自动安装并启动 **Nginx**，无需手动 SSH。

---

## 架构图

```
Internet
   │
   ▼
Internet Gateway
   │
   ▼
VPC (10.0.0.0/16)
   └── Public Subnet (10.0.1.0/24)
           │
           ▼
       Security Group
       ├── Ingress: 80, 443 (0.0.0.0/0)
       └── Ingress: 22 (your IP)
           │
           ▼
       EC2 t3.micro (Amazon Linux 2023 + Nginx)
           │
           ▼
       Elastic IP (静态公网 IP)
```

## 前置条件

1. **AWS CLI** — 已安装并配置好凭证：
   ```bash
   aws configure
   # 或设置环境变量：
   export AWS_ACCESS_KEY_ID=...
   export AWS_SECRET_ACCESS_KEY=...
   export AWS_DEFAULT_REGION=us-east-1
   ```

2. **Terraform >= 1.3** — [安装指南](https://developer.hashicorp.com/terraform/install)
   ```bash
   terraform -version
   ```

## 快速开始

```bash
# 1. 克隆仓库
git clone <repo-url>
cd terraform-aws-web-server

# 2. 复制并编辑变量文件
cp terraform.tfvars.example terraform.tfvars
# 编辑 terraform.tfvars，将 allowed_ssh_cidr 改为你的 IP

# 3. 初始化 Terraform（下载 AWS Provider）
terraform init

# 4. 预览将要创建的资源
terraform plan

# 5. 创建资源（输入 yes 确认）
terraform apply
```

Apply 完成后，终端会输出：

```
Outputs:

public_ip  = "x.x.x.x"
public_dns = "ec2-x-x-x-x.compute-1.amazonaws.com"
instance_id = "i-xxxxxxxxxxxxxxxxx"
ssh_command = "ssh -i <your-key.pem> ec2-user@x.x.x.x"
```

## 验证 Nginx

等待约 60 秒让 user_data 脚本执行完成，然后在浏览器访问：

```
http://<public_ip>
```

应该看到 **Nginx 默认欢迎页面**。

## 销毁资源

**重要：** 不使用时务必销毁，避免产生 AWS 费用。

```bash
terraform destroy
```

## 文件说明

| 文件 | 说明 |
|---|---|
| `main.tf` | 所有 AWS 资源定义，含详细注释 |
| `variables.tf` | 所有输入变量及说明 |
| `outputs.tf` | Apply 后输出的关键信息 |
| `userdata.sh` | EC2 启动时执行的 Nginx 安装脚本 |
| `terraform.tfvars.example` | 变量配置示例，复制为 `.tfvars` 使用 |

## 安全注意事项

- `allowed_ssh_cidr` 默认为 `0.0.0.0/0`（全开放）— **生产环境务必改为你的 IP**
- `terraform.tfvars` 和 `*.tfstate` 已在 `.gitignore` 中排除，**不要手动提交**
- State 文件包含资源 ID 等敏感信息，生产环境应使用远程 State（如 S3 + DynamoDB）
```

**Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add README with architecture, quickstart, and security notes"
```

---

### Task 8: Final validation — terraform plan dry run

**Step 1: Run terraform plan (no credentials needed for syntax check)**

```bash
cd /Users/hangchengliu/Documents/GitHub/terraform-aws-web-server
terraform init
terraform validate
```

Expected: `Success! The configuration is valid.`

**Step 2: Verify .gitignore is working**

```bash
git status
```

Expected: working tree clean. If `.terraform/` or any `.tfstate` files appear, something is wrong with `.gitignore`.

**Step 3: Review all committed files**

```bash
git log --oneline
```

Expected output (7 commits):
```
<hash> docs: add README with architecture, quickstart, and security notes
<hash> docs: add terraform.tfvars.example with safe placeholder values
<hash> feat: add outputs (public_ip, public_dns, instance_id, ssh_command)
<hash> feat: add all AWS resources (VPC, subnet, IGW, SG, EC2, EIP)
<hash> feat: add Nginx user_data bootstrap script
<hash> feat: add input variables
<hash> chore: initial repo scaffold with .gitignore and design doc
```

**Step 4: Final commit if any loose files remain**

```bash
git status
# If clean, nothing to do. If there are untracked files, add and commit them.
```

---

## Summary

After completing all tasks, the repo contains:

```
terraform-aws-web-server/
├── .gitignore
├── README.md
├── main.tf                   # VPC, subnet, IGW, route table, SG, EC2, EIP
├── variables.tf              # All inputs with descriptions
├── outputs.tf                # public_ip, public_dns, instance_id, ssh_command
├── userdata.sh               # Nginx install via dnf
├── terraform.tfvars.example  # Safe example — committed
└── docs/plans/
    ├── 2026-03-05-web-server-design.md
    └── 2026-03-05-terraform-aws-web-server.md
```

A user can `git clone`, `cp terraform.tfvars.example terraform.tfvars`, run `terraform apply`, and have a live Nginx server in under 5 minutes.
