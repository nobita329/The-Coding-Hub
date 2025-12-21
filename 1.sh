#!/bin/bash

# ================= COLORS =================
G="\e[32m"; R="\e[31m"; Y="\e[33m"
C="\e[36m"; W="\e[97m"; N="\e[0m"

# ================= ROOT CHECK =================
if [ "$EUID" -ne 0 ]; then
  echo -e "${R}❌ Root user required${N}"
  exit 1
fi

# ================= DOCKER CHECK =================
if ! command -v docker &>/dev/null; then
  echo -e "${Y}🐳 Docker not found, installing...${N}"
  apt update -y && apt install -y docker.io
  systemctl enable --now docker
fi

# ================= MENU =================
clear
echo -e "${C}════════════ DOCKER SYSTEM MENU ════════════${N}"
echo -e "${G}1) Create Container${N}"
echo -e "${Y}2) Exit${N}"
read -p "Choose [1-2]: " MAIN

[ "$MAIN" = "2" ] && exit 0
[ "$MAIN" != "1" ] && echo "Invalid choice" && exit 1

# ================= INPUTS =================
read -p "Container name [sys_container]: " NAME
NAME=${NAME:-sys_container}

read -p "RAM in GB [2]: " RAM
RAM=${RAM:-2}

read -p "CPU cores [1]: " CPU
CPU=${CPU:-1}

read -p "SSD size in GB [20]: " SSD
SSD=${SSD:-20}

read -p "Port mapping (e.g. 8080:80) [skip]: " PORT

# ================= IMAGE SELECTION =================
clear
echo -e "${C}════════════ AVAILABLE SYSTEMD IMAGES ════════════${N}"
echo "1) Ubuntu 22.04 (Recommended)"
echo "2) Debian 11"
read -p "Choose [1-2]: " IMG

case $IMG in
  2) IMAGE="jrei/systemd-debian:11" ;;
  *) IMAGE="jrei/systemd-ubuntu:22.04" ;;
esac

echo -e "${Y}[*] Pulling image if required...${N}"
docker pull $IMAGE

# ================= CLEAN OLD =================
docker rm -f "$NAME" &>/dev/null

# ================= CREATE VOLUME =================
docker volume create ${NAME}-data &>/dev/null

# ================= BUILD RUN CMD =================
RUN_CMD="docker run -dit \
  --name $NAME \
  --hostname $NAME \
  --privileged \
  --cgroupns=host \
  --memory ${RAM}g \
  --cpus $CPU \
  --storage-opt size=${SSD}G \
  -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
  -v ${NAME}-data:/data \
  --tmpfs /run \
  --tmpfs /run/lock \
  --tmpfs /tmp \
  --restart unless-stopped"

[ -n "$PORT" ] && RUN_CMD="$RUN_CMD -p $PORT"

RUN_CMD="$RUN_CMD $IMAGE /sbin/init"

# ================= CREATE =================
clear
echo -e "${C}════════════ CONTAINER CREATION ════════════${N}"
echo -e "${W}Command:${N}"
echo "$RUN_CMD"
echo

eval $RUN_CMD

# ================= RESULT =================
if [ $? -eq 0 ]; then
  echo -e "${G}[✓] Container created successfully${N}"
  echo -e "${C}Entering container system...${N}"
  sleep 2
  docker exec -it "$NAME" bash
else
  echo -e "${R}[✗] Container creation failed${N}"
fi
