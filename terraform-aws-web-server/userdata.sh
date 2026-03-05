#!/bin/bash
set -euxo pipefail
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
