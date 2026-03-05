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
