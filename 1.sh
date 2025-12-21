#!/bin/bash

# ========= Colors =========
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

clear
echo -e "${BLUE}
╔════════════════════════════════════════════╗
║        SECURE DATABASE SETUP               ║
║        (With Security Considerations)      ║
╚════════════════════════════════════════════╝
${NC}"

# ===== Install with security =====
echo -e "${YELLOW}⚙️ Installing MySQL/MariaDB securely...${NC}"
sudo apt update
sudo apt install -y mysql-server

# ===== Secure MySQL Installation =====
echo -e "${YELLOW}⚙️ Running MySQL secure installation...${NC}"
sudo mysql_secure_installation <<EOF

y
0
$DB_ROOT_PASS
$DB_ROOT_PASS
y
y
y
y
EOF

# ===== Input with validation =====
while true; do
    read -rp "Enter Database Username: " DB_USER
    if [[ -n "$DB_USER" ]]; then
        break
    fi
    echo -e "${RED}Username cannot be empty!${NC}"
done

while true; do
    read -srp "Enter Database Password (min 8 chars): " DB_PASS
    echo
    if [[ ${#DB_PASS} -ge 8 ]]; then
        read -srp "Confirm Password: " DB_PASS2
        echo
        if [[ "$DB_PASS" == "$DB_PASS2" ]]; then
            break
        else
            echo -e "${RED}Passwords don't match!${NC}"
        fi
    else
        echo -e "${RED}Password must be at least 8 characters!${NC}"
    fi
done

read -rp "Allow remote access? (y/n): " ALLOW_REMOTE

# ===== Create User =====
echo -e "${YELLOW}⚙️ Creating database user...${NC}"
sudo mysql -u root -p"$DB_ROOT_PASS" <<MYSQL_SCRIPT
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON *.* TO '${DB_USER}'@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;
MYSQL_SCRIPT

# ===== Conditional Remote Access =====
if [[ "$ALLOW_REMOTE" == "y" || "$ALLOW_REMOTE" == "Y" ]]; then
    read -rp "Allow from specific IP (enter for any): " ALLOW_IP
    ALLOW_IP=${ALLOW_IP:-%}
    
    sudo mysql -u root -p"$DB_ROOT_PASS" <<MYSQL_SCRIPT
CREATE USER IF NOT EXISTS '${DB_USER}'@'${ALLOW_IP}' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON *.* TO '${DB_USER}'@'${ALLOW_IP}' WITH GRANT OPTION;
FLUSH PRIVILEGES;
MYSQL_SCRIPT
    
    # Configure bind address
    CONF_FILE="/etc/mysql/mariadb.conf.d/50-server.cnf"
    if [ -f "$CONF_FILE" ]; then
        sudo sed -i 's/^bind-address.*/bind-address = 0.0.0.0/' "$CONF_FILE"
        echo -e "${GREEN}✔ Remote access enabled for IP: ${ALLOW_IP}${NC}"
        
        if command -v ufw &>/dev/null; then
            sudo ufw allow 3306/tcp
            echo -e "${GREEN}✔ Port 3306 opened in firewall${NC}"
        fi
    fi
fi

# ===== Restart Services =====
sudo systemctl restart mysql

# ===== Show Connection Info =====
echo -e "${GREEN}
✅ DATABASE SETUP COMPLETE
==========================
Username    : $DB_USER
Password    : [hidden]
Local Host  : localhost
${NC}"

if [[ "$ALLOW_REMOTE" == "y" || "$ALLOW_REMOTE" == "Y" ]]; then
    echo -e "${GREEN}Remote Host : ${ALLOW_IP}${NC}"
fi

echo -e "${YELLOW}
⚠️  SECURITY NOTES:
1. Keep your password secure
2. Consider using SSH tunneling instead of direct remote access
3. Regularly update MySQL and your OS
4. Consider using a more restricted privilege set
${NC}"
