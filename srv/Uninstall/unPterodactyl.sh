#!/bin/bash
# ====================================================
#          PTERODACTYL INSTALL / UPDATE / UNINSTALL
# ====================================================

GREEN="\033[1;32m"
RED="\033[1;31m"
YELLOW="\033[1;33m"
CYAN="\033[1;36m"
NC="\033[0m"

# ================== INSTALL FUNCTION ==================
install_ptero() {
    clear
    echo -e "${CYAN}"
    echo "┌──────────────────────────────────────────────┐"
    echo "│            Pterodactyl Installation          │"
    echo "└──────────────────────────────────────────────┘${NC}"
    bash <(curl -s https://raw.githubusercontent.com/nobita329/The-Coding-Hub/refs/heads/main/srv/panel/pterodactyl.sh) 
    echo -e "${GREEN}✔ Installation Complete${NC}"
    read -p "Press Enter to return..."
}

# ================= PANEL UNINSTALL =================
uninstall_panel() {
    echo ">>> Stopping Panel service..."
    sudo systemctl stop pteroq.service || true
    sudo systemctl disable pteroq.service || true
    sudo rm -f /etc/systemd/system/pteroq.service
    sudo systemctl daemon-reload

    echo ">>> Removing Panel cronjob..."
    sudo crontab -l | grep -v 'php /var/www/pterodactyl/artisan schedule:run' | sudo crontab - || true

    echo ">>> Removing Panel files..."
    sudo rm -rf /var/www/pterodactyl

    echo ">>> Removing Panel MySQL database & user..."
    sudo mysql -u root -e "DROP DATABASE IF EXISTS panel;"
    sudo mysql -u root -e "DROP USER IF EXISTS 'pterodactyl'@'127.0.0.1';"
    sudo mysql -u root -e "FLUSH PRIVILEGES;"

    echo ">>> Cleaning Nginx configs..."
    [ -f /etc/nginx/sites-enabled/pterodactyl.conf ] && sudo rm -f /etc/nginx/sites-enabled/pterodactyl.conf
    [ -f /etc/nginx/sites-available/pterodactyl.conf ] && sudo rm -f /etc/nginx/sites-available/pterodactyl.conf
    sudo systemctl reload nginx || true

    echo "✅ Panel uninstalled successfully!"
}

uninstall_ptero() {
    clear
    echo -e "${CYAN}"
    echo "┌──────────────────────────────────────────────┐"
    echo "│           Pterodactyl Uninstallation         │"
    echo "└──────────────────────────────────────────────┘${NC}"

    uninstall_panel
    echo -e "${GREEN}✔ Pterodactyl Panel Uninstalled (Wings Not Removed)${NC}"
    read -p "Press Enter to return..."
}

# ================= UPDATE FUNCTION =================
update_panel() {
clear
echo "==============================================="
echo "      🚀 PTERODACTYL PANEL UPDATE SCRIPT 🚀    "
echo "==============================================="
echo ""

echo ">>> Starting Pterodactyl Panel Update..."

cd /var/www/pterodactyl || { echo "❌ Panel directory not found!"; read; return; }

echo "⚙️ Putting panel into maintenance mode..."
php artisan down

echo "⬇️ Downloading latest Panel release..."
curl -L https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz | tar -xzv

echo "🔑 Setting correct permissions..."
chmod -R 755 storage/* bootstrap/cache

echo "📦 Running composer install..."
composer install --no-dev --optimize-autoloader

echo "🧹 Clearing cache..."
php artisan view:clear
php artisan config:clear

echo "📂 Running migrations..."
php artisan migrate --seed --force

echo "👤 Setting ownership..."
chown -R www-data:www-data /var/www/pterodactyl/*

echo "♻️ Restarting queue..."
php artisan queue:restart

echo "✅ Panel back online."
php artisan up

echo ""
echo "==============================================="
echo " 🎉 Pterodactyl Panel Update Complete! 🎉 "
echo "==============================================="
read -p "Press Enter to return..."
}

# ===================== MENU =====================
while true; do
clear
echo -e "${YELLOW}"
echo "╔═══════════════════════════════════════════════╗"
echo "║           PTERODACTYL CONTROL MENU            ║"
echo "╠═══════════════════════════════════════════════╣"
echo -e "║ ${GREEN}1) Install ${NC}                           "
echo -e "║"
echo -e "║ ${CYAN}2) Update ${NC}                                   "
echo -e "║"
echo -e "║ ${RED}3) Uninstall${NC}            "
echo -e "║"
echo -e "║ 4) Exit                                         "
echo "╚═══════════════════════════════════════════════╝"
echo -ne "${CYAN}Select Option: ${NC}"; read choice

case $choice in
    1) install_ptero ;;
    2) update_panel ;;
    3) uninstall_ptero ;;
    4) clear; exit ;;
    *) echo -e "${RED}Invalid option...${NC}"; sleep 1 ;;
esac
done
