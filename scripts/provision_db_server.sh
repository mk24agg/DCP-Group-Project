#!/bin/bash
# QNI Group Project - Database Server Provisioning Script
# Author: [Your Name] | Module: 5COM2008 | Date: 2026
# Usage: chmod +x provision_db_server.sh && sudo ./provision_db_server.sh

set -e
LOG_FILE="/var/log/provision_db.log"
exec 2>&1 | tee -a "$LOG_FILE"

APP_SERVER_IP="${1:-10.0.0.0}"  # Pass app server private IP as argument
DB_NAME="webapp_db"
DB_USER="webapp_user"
DB_PASS="SecureP@ssw0rd2026!"

echo "=========================================="
echo "  DB Server Provisioning — $(date)"
echo "=========================================="

# ── 1. SYSTEM UPDATE ──────────────────────────────────────────────────────
echo "[1/6] Updating system..."
apt-get update -y && apt-get upgrade -y

# ── 2. INSTALL MYSQL ──────────────────────────────────────────────────────
echo "[2/6] Installing MySQL Server..."
apt-get install -y mysql-server
systemctl enable mysql
systemctl start mysql

# ── 3. SECURE MYSQL ───────────────────────────────────────────────────────
echo "[3/6] Securing MySQL installation..."
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'RootSecure2026!';"
mysql -u root -p'RootSecure2026!' -e "DELETE FROM mysql.user WHERE User='';"
mysql -u root -p'RootSecure2026!' -e "DROP DATABASE IF EXISTS test;"
mysql -u root -p'RootSecure2026!' -e "FLUSH PRIVILEGES;"

# ── 4. CREATE APPLICATION DATABASE ───────────────────────────────────────
echo "[4/6] Creating application database and user..."
mysql -u root -p'RootSecure2026!' << SQL
CREATE DATABASE IF NOT EXISTS ${DB_NAME};
CREATE USER IF NOT EXISTS '${DB_USER}'@'${APP_SERVER_IP}' IDENTIFIED BY '${DB_PASS}';
GRANT SELECT, INSERT, UPDATE, DELETE ON ${DB_NAME}.* TO '${DB_USER}'@'${APP_SERVER_IP}';
FLUSH PRIVILEGES;
SQL
echo "Database ${DB_NAME} created. User ${DB_USER} granted access from ${APP_SERVER_IP}."

# ── 5. CONFIGURE MYSQL TO ACCEPT REMOTE CONNECTIONS FROM APP SERVER ONLY ─
echo "[5/6] Configuring MySQL network binding..."
sed -i "s/bind-address.*/bind-address = 0.0.0.0/" /etc/mysql/mysql.conf.d/mysqld.cnf
systemctl restart mysql

# ── 6. FIREWALL ───────────────────────────────────────────────────────────
echo "[6/6] Configuring UFW firewall..."
ufw --force enable
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow from "${APP_SERVER_IP}" to any port 3306
ufw status verbose

echo "=========================================="
echo "  DB Provisioning COMPLETE — $(date)"
echo "  MySQL accessible from App Server: ${APP_SERVER_IP}:3306"
echo "  Database: ${DB_NAME} | User: ${DB_USER}"
echo "=========================================="
