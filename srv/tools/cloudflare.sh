#!/bin/bash

# ==========================================
#     CLOUDLFARED INSTALLER & UNINSTALLER
# ==========================================

GREEN="\033[1;32m"
RED="\033[1;31m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
NC="\033[0m"

install_cloudflared() {
    clear
    echo -e "${BLUE}┌────────────────────────────────────┐"
    echo -e "│      Installing Cloudflared       │"
    echo -e "└────────────────────────────────────┘${NC}"

    sudo mkdir -p --mode=0755 /usr/share/keyrings
    curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg \
    | sudo tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null

    echo 'deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main' \
    | sudo tee /etc/apt/sources.list.d/cloudflared.list

    sudo apt update && sudo apt install -y cloudflared

    if command -v cloudflared >/dev/null 2>&1; then
        echo -e "${GREEN}✔ Cloudflared Installed Successfully${NC}"
    else
        echo -e "${RED}✘ Installation Failed${NC}"
    fi
}

uninstall_cloudflared() {
    clear
    echo -e "${BLUE}┌────────────────────────────────────┐"
    echo -e "│      Uninstalling Cloudflared     │"
    echo -e "└────────────────────────────────────┘${NC}"

    sudo cloudflared service uninstall 2>/dev/null
    sudo apt remove -y cloudflared
    sudo rm -f /etc/apt/sources.list.d/cloudflared.list
    sudo rm -f /usr/share/keyrings/cloudflare-main.gpg

    echo -e "${GREEN}✔ Cloudflared + Service Removed Completely${NC}"
}

while true; do
    clear
    echo -e "${YELLOW}"
    echo "╔═════════════════════════════════════════════╗"
    echo "║        CLOUDLFARED MANAGEMENT MENU          ║"
    echo "╠═════════════════════════════════════════════╣"
    echo -e "║"
    echo -e "║ ${GREEN}1) Install ${NC}                         ║"
    echo -e "║"
    echo -e "║ ${RED}2) Uninstall ${NC}                       ║"
    echo -e "║"
    echo -e "║ 3) Exit                                      ║"
    echo "╚═════════════════════════════════════════════╝"
    echo -ne "${BLUE}Select an option: ${NC}"
    read choice

    case $choice in
        1) install_cloudflared ;;
        2) uninstall_cloudflared ;;
        3) clear; exit ;;
        *) echo -e "${RED}Invalid Option!${NC}"; sleep 1 ;;
    esac
done
