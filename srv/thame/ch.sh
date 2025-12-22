#!/bin/bash

# ========== COLORS ==========
R="\e[31m"; G="\e[32m"; Y="\e[33m"
B="\e[34m"; M="\e[35m"; C="\e[36m"
W="\e[97m"; N="\e[0m"

# ========== HEADER ==========
header() {
  clear
  echo -e "${B}"
  echo "╔════════════════════════════════════════════╗"
  echo "║        🧩 BLUEPRINT CONTROL MENU           ║"
  echo "╠════════════════════════════════════════════╣"
  echo "║   Minimal • Clean • No Bakchodi            ║"
  echo "╚════════════════════════════════════════════╝"
  echo -e "${N}"
}

pause() {
  echo
  read -rp "↩️  Press Enter to return to menu..."
}

# ========== MENU ==========
menu() {
  header
  echo -e "${C}Choose your destiny:${N}\n"
  echo -e "${G}1) 🚀 BLUEPRINT 1 (Normal Install / Run)"
  echo -e "${Y}2) ⚡ BLUEPRINT 2 (Rebuild / Fresh UI)"
  echo -e "${R}0) ❌ Exit${N}\n"
  read -rp "👉 Select option: " opt
}

# ========== ACTIONS ==========
blueprint1() {
  header
  echo -e "${G}▶ Running BLUEPRINT 1...${N}"
  cd /var/www/pterodactyl || exit
  bash blueprint.sh
  pause
}

blueprint2() {
  header
  echo -e "${Y}▶ Running BLUEPRINT 2 (Fresh rebuild)...${N}"


  echo -e "${C}• Launching Blueprint again...${N}"
  bash blueprint.sh
  pause
}

# ========== LOOP ==========
while true; do
  menu
  case $opt in
    1) blueprint1 ;;
    2) blueprint2 ;;
    0) echo -e "${M}👋 Exit. Panel shant ho gaya.${N}"; exit ;;
    *) echo -e "${R}❌ Galat choice. Phir se try kar.${N}"; sleep 1 ;;
  esac
done

