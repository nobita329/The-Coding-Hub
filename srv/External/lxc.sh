#!/bin/bash
set -e

# ========= COLORS =========
R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'
C='\033[0;36m'; N='\033[0m'

pause(){ read -p "Press Enter to continue..."; }
header(){
clear
echo -e "${C}══════════════════════════════════════"
echo "   LXC / LXD MANAGER (AUTO FULL)"
echo -e "══════════════════════════════════════${N}"
}

# ========= OS DETECT =========
if [[ -f /etc/os-release ]]; then
  . /etc/os-release
  OS=$ID
else
  echo -e "${R}Cannot detect OS${N}"
  exit 1
fi

# ========= AUTO DEPENDENCY =========
auto_install(){
header
echo -e "${Y}Auto installing LXC / LXD dependencies...${N}"

sudo apt update && sudo apt upgrade -y
sudo apt install -y lxc lxc-utils bridge-utils uidmap

if ! command -v snap >/dev/null 2>&1; then
  sudo apt install -y snapd
fi

sudo systemctl enable --now snapd.socket

[[ ! -e /snap ]] && sudo ln -s /var/lib/snapd/snap /snap || true

if ! command -v lxd >/dev/null 2>&1; then
  sudo snap install lxd
fi

sudo usermod -aG lxd $USER

if ! lxc info >/dev/null 2>&1; then
  echo -e "${Y}Initializing LXD (auto)...${N}"
  sudo lxd init --auto
fi

echo -e "${G}Dependencies installed ✔${N}"
echo -e "${Y}NOTE:${N} If first time install, logout/login recommended"
pause
}

# ========= CHECK =========
if ! command -v lxc >/dev/null 2>&1; then
  auto_install
fi

# ========= AUTO DETECT =========
AUTO_CPU=$(nproc)
AUTO_RAM=$(free -m | awk '/^Mem:/ {print int($2/2)}')
AUTO_DISK=10

# ========= CREATE =========
create_container(){
header
read -p "Container name: " name
[[ -z "$name" ]] && return

echo "1) Ubuntu 22.04"
echo "2) Ubuntu 24.04"
echo "3) Debian 11"
echo "4) Debian 12"
echo "5) Debian 13"
echo "6) AlmaLinux 9"
echo "7) Rocky Linux 9"
echo "8) CentOS Stream 9"
echo "9) Fedora 40"
read -p "Select OS: " os

case $os in
1) img="ubuntu/22.04" ;;
2) img="ubuntu/24.04" ;;
3) img="debian/11" ;;
4) img="debian/12" ;;
5) img="debian/13" ;;
6) img="almalinux/9" ;;
7) img="rockylinux/9" ;;
8) img="centos/stream9" ;;
9) img="fedora/40" ;;
*) echo "Invalid"; pause; return ;;
esac

echo -e "${Y}AUTO:${N} CPU=$AUTO_CPU RAM=${AUTO_RAM}MB DISK=${AUTO_DISK}GB"
read -p "CPU cores (Enter=auto): " cpu
read -p "RAM MB (Enter=auto): " ram
read -p "Disk GB (Enter=auto): " disk

cpu=${cpu:-$AUTO_CPU}
ram=${ram:-$AUTO_RAM}
disk=${disk:-$AUTO_DISK}

lxc launch images:$img $name
lxc config set $name limits.cpu $cpu
lxc config set $name limits.memory ${ram}MB
lxc config device set $name root size=${disk}GB

echo -e "${G}Container created ✔${N}"
pause
}

# ========= EDIT =========
edit_container(){
header
lxc list -c n --format csv || { pause; return; }
read -p "Container name: " name

while true; do
header
echo -e "${Y}EDIT → $name${N}"
echo "1) CPU"
echo "2) RAM"
echo "3) Disk"
echo "4) Network attach"
echo "5) Enable nesting"
echo "6) Enable privileged"
echo "7) Show config"
echo "0) Back"
read -p "Select: " e

case $e in
1) read -p "CPU cores: " v; lxc config set $name limits.cpu $v ;;
2) read -p "RAM (e.g. 2GB): " v; lxc config set $name limits.memory $v ;;
3) read -p "Disk (e.g. 20GB): " v; lxc config device set $name root size=$v ;;
4) lxc network list; read -p "Network (default lxdbr0): " n; n=${n:-lxdbr0}; lxc network attach $n $name eth0 ;;
5) lxc config set $name security.nesting true ;;
6) lxc config set $name security.privileged true ;;
7) lxc config show $name ; pause ;;
0) return ;;
*) ;;
esac
done
}

# ========= MANAGE =========
manage_container(){
header
lxc list -c n --format csv || { pause; return; }
read -p "Container name: " name

while true; do
header
status=$(lxc list $name -c s --format csv)
echo -e "${Y}$name${N} | ${G}$status${N}"
echo "1) Start"
echo "2) Stop"
echo "3) Restart"
echo "4) Shell"
echo "5) Edit"
echo "6) Delete"
echo "0) Back"
read -p "Select: " c

case $c in
1) lxc start $name ;;
2) lxc stop $name ;;
3) lxc restart $name ;;
4) lxc exec $name -- bash ;;
5) edit_container ;;
6) read -p "Confirm delete (y/N): " x; [[ $x =~ ^[Yy]$ ]] && lxc delete $name --force && return ;;
0) return ;;
*) ;;
esac
done
}

# ========= MENU =========
while true; do
header
echo "1) Auto Install Dependencies"
echo "2) Create Container (Auto)"
echo "3) List Containers"
echo "4) Manage / Edit Container"
echo "0) Exit"
read -p "Select: " m

case $m in
1) auto_install ;;
2) create_container ;;
3) lxc list ; pause ;;
4) manage_container ;;
0) exit ;;
*) ;;
esac
done
