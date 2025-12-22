#!/bin/bash

# ================= COLORS =================
R="\e[31m"; G="\e[32m"; Y="\e[33m"
B="\e[34m"; M="\e[35m"; C="\e[36m"
W="\e[97m"; N="\e[0m"

# ================= UI FUNCTIONS =================
header() {
  clear
  echo -e "${M}"
  echo "╔══════════════════════════════════════════════════════╗"
  echo "║        🚀 PTERODACTYL BLUEPRINT INSTALLER            ║"
  echo "╠══════════════════════════════════════════════════════╣"
  echo "║      UI • Auto • Clean • No Bakchodi                 ║"
  echo "╚══════════════════════════════════════════════════════╝"
  echo -e "${N}"
}

step() {
  echo -e "${C}➜ $1${N}"
}

ok() {
  echo -e "${G}✔ $1${N}"
}

fail() {
  echo -e "${R}✘ $1${N}"
  exit 1
}

# ================= CHECK ROOT =================
if [ "$EUID" -ne 0 ]; then
  fail "Please run as root"
fi

# ================= VARIABLES =================
export PTERODACTYL_DIRECTORY=/var/www/pterodactyl

# ================= START =================
header
step "Installing base dependencies (curl, wget, unzip)"
apt update -y && apt install -y curl wget unzip ca-certificates git gnupg zip || fail "Deps install failed"
ok "Base dependencies installed"

step "Switching to Pterodactyl directory"
cd "$PTERODACTYL_DIRECTORY" || fail "Pterodactyl directory not found"

step "Downloading Blueprint Framework (latest)"
wget "$(curl -s https://api.github.com/repos/BlueprintFramework/framework/releases/latest | grep browser_download_url | cut -d '"' -f 4)" -O release.zip || fail "Download failed"
wget https://github.com/BlueprintFramework/framework/releases/download/beta-2025-12/release.zip
unzip -o release.zip || fail "Unzip failed"
ok "Blueprint downloaded & extracted"

# ================= NODE.JS =================
step "Installing Node.js 20.x"
mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" \
> /etc/apt/sources.list.d/nodesource.list

apt update -y && apt install -y nodejs || fail "Node.js install failed"
ok "Node.js installed"

# ================= YARN & DEPENDENCIES =================
step "Installing Yarn & Node dependencies"
npm i -g yarn || fail "Yarn install failed"
yarn install || fail "Yarn dependencies failed"
ok "Node dependencies ready"

# ================= BLUEPRINT CONFIG =================
step "Creating .blueprintrc configuration"
cat <<EOF > "$PTERODACTYL_DIRECTORY/.blueprintrc"
WEBUSER="www-data";
OWNERSHIP="www-data:www-data";
USERSHELL="/bin/bash";
EOF
ok ".blueprintrc created"

# ================= PERMISSIONS =================
step "Setting permissions"
chmod +x "$PTERODACTYL_DIRECTORY/blueprint.sh" || fail "Permission failed"
chown -R www-data:www-data "$PTERODACTYL_DIRECTORY"
ok "Permissions fixed"

# ================= RUN BLUEPRINT =================
step "Launching Blueprint installer"
bash "$PTERODACTYL_DIRECTORY/blueprint.sh"

# ================= DONE =================
echo -e "\n${G}🎉 Blueprint UI Installation Complete!${N}"
echo -e "${Y}Panel breathe kar raha hai… theme lagao, flex maro 😏${N}"
