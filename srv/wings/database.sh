#!/bin/bash

# ========= Colors =========
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

clear
echo -e "${BLUE}
╔════════════════════════════════════╗
║      AUTO DATABASE SETUP MENU      ║
║      No Password | No Prompt       ║
╚════════════════════════════════════╝
${NC}"

# ===== Input =====
read -rp "Enter Database Username [default: root]: " DB_USER
read -rp "Enter Database Password [default: root]: " DB_PASS

# Set defaults if empty
DB_USER=${DB_USER:-root}
DB_PASS=${DB_PASS:-root}

echo -e "${YELLOW}⚙️ Using DB User: ${DB_USER}${NC}"

echo -e "${YELLOW}⚙️ Creating database user...${NC}"
sudo apt update && apt -y install mariadb-server mariadb-client
sudo apt update && sudo apt install -y mysql-server && sudo systemctl enable --now mysql mariadb
sudo systemctl enable mysql
sudo systemctl enable mariadb
sudo systemctl restart mysql
sudo systemctl restart mariadb

# ===== MySQL (NO PASSWORD, NO PROMPT) =====
sudo mysql <<MYSQL_SCRIPT
CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON *.* TO '${DB_USER}'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
MYSQL_SCRIPT

# ===== Enable Remote Access =====
CONF_FILE="/etc/mysql/mariadb.conf.d/50-server.cnf"

if [ -f "$CONF_FILE" ]; then
    sed -i 's/^bind-address.*/bind-address = 0.0.0.0/' "$CONF_FILE"
    echo -e "${GREEN}✔ bind-address set to 0.0.0.0${NC}"
else
    echo -e "${RED}⚠ MySQL config file not found${NC}"
fi

# ===== Restart Services =====
systemctl restart mysql 2>/dev/null
systemctl restart mariadb 2>/dev/null

# ===== Open Firewall Port =====
if command -v ufw &>/dev/null; then
    ufw allow 3306/tcp >/dev/null 2>&1
    echo -e "${GREEN}✔ Port 3306 opened${NC}"
fi

# ===== Done =====
echo -e "${GREEN}
✅ DATABASE SETUP COMPLETE
User      : $DB_USER
Password  : $DB_PASS
Remote DB : Enabled
${NC}"
