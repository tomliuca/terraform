# Design: terraform-aws-web-server

**Date:** 2026-03-05
**Status:** Approved

## Summary

A production-quality, well-commented Terraform template that provisions a complete AWS web server environment from scratch. Intended as a reusable starting point for real projects, with inline comments explaining the purpose of each resource.

## Architecture

```
Internet
   │
   ▼
IGW (Internet Gateway)
   │
   ▼
VPC (10.0.0.0/16)
   └── Public Subnet (10.0.1.0/24, us-east-1a)
           │
           ▼
       Security Group
       ├── Ingress: 80  (HTTP)  — 0.0.0.0/0
       ├── Ingress: 443 (HTTPS) — 0.0.0.0/0
       ├── Ingress: 22  (SSH)   — allowed_ssh_cidr variable
       └── Egress:  all         — 0.0.0.0/0
           │
           ▼
       EC2 t3.micro (Amazon Linux 2023)
       ├── user_data: installs & starts Nginx
       └── Elastic IP (survives stop/start)
```

## File Structure

```
terraform-aws-web-server/
├── main.tf                   # All resources: VPC, subnet, IGW, route table, SG, EC2, EIP
├── variables.tf              # Input variables with descriptions and defaults
├── outputs.tf                # public_ip, public_dns, instance_id
├── userdata.sh               # Amazon Linux 2023: dnf install nginx + systemctl enable/start
├── terraform.tfvars.example  # Safe example values to commit (no secrets)
├── .gitignore                # Excludes *.tfstate, *.tfvars, .terraform/
└── README.md                 # Prerequisites, init/plan/apply steps, verify in browser, destroy
```

## Key Decisions

| Decision | Choice | Reason |
|---|---|---|
| IaC tool | Terraform | Industry standard, multi-cloud, large community |
| Structure | Flat single-module | Simplest clone-and-run experience |
| OS | Amazon Linux 2023 | Uses `dnf`, modern, AWS-supported long-term |
| Instance type | t3.micro (variable) | Free tier eligible, easily overridden |
| Web server | Nginx via user_data | Installed at launch, no manual SSH needed |
| Public IP | Elastic IP | Survives EC2 stop/start cycles |
| SSH CIDR | Variable, default `0.0.0.0/0` | Comment warns user to restrict to their IP |
| Remote state | None (local) | Keeps template self-contained; README notes upgrade path |
| Committed secrets | None | `.gitignore` excludes `*.tfvars` and state files |

## Code Style

- Well-commented: every resource block has a comment explaining *why* it exists and how it connects to adjacent resources
- Production-quality: proper input validation, sensible defaults, no hardcoded values
- README covers: prerequisites (AWS CLI, Terraform), `terraform init/plan/apply`, browser verification, `terraform destroy`
