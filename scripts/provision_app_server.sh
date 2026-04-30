#!/bin/bash
# QNI Group Project - Application Server Provisioning Script
# Author: [Your Name] | Module: 5COM2008 | Date: 2026
# Usage: chmod +x provision_app_server.sh && sudo ./provision_app_server.sh
# Description: Provisions and configures Nginx web server with SSL and WordPress

set -e  # Exit immediately on any error
set -o pipefail

LOG_FILE="/var/log/provision_app.log"
exec 2>&1 | tee -a "$LOG_FILE"

echo "=========================================="
echo "  App Server Provisioning — $(date)"
echo "=========================================="

# ── 1. SYSTEM UPDATE ──────────────────────────────────────────────────────
echo "[1/8] Updating system packages..."
apt-get update -y && apt-get upgrade -y

# ── 2. INSTALL NGINX ──────────────────────────────────────────────────────
echo "[2/8] Installing Nginx..."
apt-get install -y nginx
systemctl enable nginx
systemctl start nginx
echo "Nginx installed. Version: $(nginx -v 2>&1)"

# ── 3. INSTALL PHP ────────────────────────────────────────────────────────
echo "[3/8] Installing PHP and extensions..."
apt-get install -y php8.1-fpm php8.1-mysql php8.1-curl php8.1-gd php8.1-mbstring php8.1-xml php8.1-zip

# ── 4. INSTALL MYSQL CLIENT ───────────────────────────────────────────────
echo "[4/8] Installing MySQL client..."
apt-get install -y mysql-client

# ── 5. CONFIGURE NGINX ────────────────────────────────────────────────────
echo "[5/8] Configuring Nginx virtual host..."
cat > /etc/nginx/sites-available/webapp << 'EOF'
server {
    listen 80;
    server_name _;
    root /var/www/html/webapp;
    index index.php index.html;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-Content-Type-Options "nosniff";
    add_header X-XSS-Protection "1; mode=block";

    location / {
        try_files $uri $uri/ /index.php?$args;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
    }

    # Block access to hidden files
    location ~ /\. {
        deny all;
    }
}
EOF

ln -sf /etc/nginx/sites-available/webapp /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx

# ── 6. INSTALL WORDPRESS ──────────────────────────────────────────────────
echo "[6/8] Installing WordPress..."
mkdir -p /var/www/html/webapp
cd /tmp
wget -q https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz
cp -r wordpress/* /var/www/html/webapp/
chown -R www-data:www-data /var/www/html/webapp
chmod -R 755 /var/www/html/webapp

# ── 7. FIREWALL CONFIGURATION ─────────────────────────────────────────────
echo "[7/8] Configuring UFW firewall..."
ufw --force enable
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 80/tcp
ufw allow 443/tcp
ufw status verbose

# ── 8. HARDEN SSH ─────────────────────────────────────────────────────────
echo "[8/8] Hardening SSH configuration..."
sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/X11Forwarding yes/X11Forwarding no/' /etc/ssh/sshd_config
systemctl restart sshd

echo "=========================================="
echo "  Provisioning COMPLETE — $(date)"
echo "  Web server accessible at: http://$(curl -s ifconfig.me)"
echo "=========================================="
