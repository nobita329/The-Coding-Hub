#!/bin/bash

# Colors
R="\e[31m"; G="\e[32m"; Y="\e[33m"
B="\e[34m"; M="\e[35m"; C="\e[36m"
W="\e[97m"; N="\e[0m"

# Check root
if [ "$EUID" -ne 0 ]; then
    echo -e "${R}Please run as root: sudo bash $0${N}"
    exit 1
fi

clear_ui() { clear; }

header() {
    clear_ui
    echo -e "${M}╔════════════════════════════════════════════╗${N}"
    echo -e "${M}║${W}     🚀 RDP + noVNC CONTROL PANEL v2.0     ${M}║${N}"
    echo -e "${M}╠════════════════════════════════════════════╣${N}"
    echo -e "${M}║${C}  XFCE • xRDP • TigerVNC • Browser Desktop ${M}║${N}"
    echo -e "${M}╚════════════════════════════════════════════╝${N}"
    echo
}

show_info() {
    IP=$(curl -s ifconfig.me || hostname -I | awk '{print $1}')
    echo -e "${C}════════════════════════════════════════════${N}"
    echo -e "${Y}🔗 Connection Info:${N}"
    echo -e "${G}RDP   :${W} $IP:3389${N}"
    echo -e "${G}noVNC :${W} http://$IP:6080/vnc.html${N}"
    echo -e "${G}VNC   :${W} $IP:5901${N}"
    echo -e "${C}════════════════════════════════════════════${N}"
    echo
}

install_all() {
    echo -e "${Y}📦 Installing Desktop + RDP + noVNC...${N}"
    
    # Update system
    apt update && apt upgrade -y
    apt update && apt upgrade -y
    apt install xrdp -y
    systemctl enable xrdp
    systemctl start xrdp
    adduser xrdp ssl-cert
    echo "startxfce4" > ~/.xsession
    sudo chown $(whoami):$(whoami) ~/.xsession
    echo "🧠 Setting default session..."
    echo xfce4-session > /etc/skel/.xsession
    echo xfce4-session > ~/.xsession

    echo "📡 Installing VNC & noVNC..."
    apt install tigervnc-standalone-server tigervnc-common novnc websockify -y
    apt install xfce4 xfce4-goodies xrdp tigervnc-standalone-server tigervnc-common novnc websockify -y
    systemctl enable xrdp && systemctl start xrdp
    adduser xrdp ssl-cert
    echo xfce4-session > ~/.xsession
    echo xfce4-session > /etc/skel/.xsession
    vncserver -localhost no :1
    # Install desktop and VNC
    apt install -y xfce4 xfce4-goodies xfce4-terminal \
        xrdp tigervnc-standalone-server tigervnc-common \
        novnc websockify firefox-esr
    
    # Configure xRDP
    systemctl enable xrdp
    systemctl start xrdp
    adduser xrdp ssl-cert
    
    # Set XFCE as default session
    echo "xfce4-session" > ~/.xsession
    echo "xfce4-session" > /etc/skel/.xsession
    chmod +x ~/.xsession
    
    # Configure VNC
    mkdir -p ~/.vnc
    echo "root" | vncpasswd -f > ~/.vnc/passwd
    chmod 600 ~/.vnc/passwd
    
    # Create VNC config
    cat > ~/.vnc/config <<EOF
geometry=1280x720
depth=24
localhost
alwaysshared
EOF
    
    # Start VNC server
    vncserver -localhost no :1
    
    # Create noVNC service
    cat > /etc/systemd/system/novnc.service <<EOF
[Unit]
Description=noVNC Server
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/websockify --web=/usr/share/novnc/ 6080 localhost:5901
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable novnc
    systemctl start novnc
    systemctl daemon-reexec
    systemctl daemon-reload
    systemctl enable novnc
    systemctl start novnc
    # Configure firewall
    ufw allow 3389/tcp
    ufw allow 6080/tcp
    ufw allow 5901/tcp
    ufw reload 2>/dev/null || true
    
    # Install additional browsers
    install_browsers
    
    echo -e "${G}✅ Installation Complete!${N}"
    show_info
    read -p "Press Enter to continue..."
}

install_browsers() {
    echo -e "${Y}🌐 Installing Web Browsers...${N}"
    
    # Chrome
    echo "Installing Google Chrome..."
    wget -q -O /tmp/chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
    apt install -y /tmp/chrome.deb 2>/dev/null || echo "Chrome installation skipped"

    # Chromium
    apt install -y chromium chromium-l10n
    
    # Brave (optional)
    read -p "Install Brave Browser? (y/n): " install_brave
    if [[ $install_brave =~ ^[Yy]$ ]]; then
        apt install -y curl
        curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg \
            https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
        echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] \
            https://brave-browser-apt-release.s3.brave.com/ stable main" \
            > /etc/apt/sources.list.d/brave-browser-release.list
        apt update
        apt install -y brave-browser
    fi

     sed -i 's|^Exec=.*google-chrome-stable.*|Exec=/usr/bin/google-chrome-stable --no-sandbox --disable-dev-shm-usage|g' /usr/share/applications/google-chrome.desktop
     sed -i 's|^Exec=.*brave-browser.*|Exec=/usr/bin/brave-browser-stable --no-sandbox --disable-dev-shm-usage|g' /usr/share/applications/brave-browser.desktop
     sed -i 's|^Exec=.*chromium.*|Exec=/usr/bin/chromium --no-sandbox --disable-dev-shm-usage|g' ~/Desktop/chromium*.desktop 2>/dev/null
     mkdir -p ~/Desktop
# Google Chrome
     cp /usr/share/applications/google-chrome.desktop ~/Desktop/ 2>/dev/null
# Firefox
     cp /usr/share/applications/firefox*.desktop ~/Desktop/ 2>/dev/null
# Chromium (Ubuntu 22 me naam different ho sakta hai)
     cp /usr/share/applications/chromium*.desktop ~/Desktop/ 2>/dev/null
# Brave
     cp /usr/share/applications/brave-browser*.desktop ~/Desktop/ 2>/dev/null
# Sabko executable banao
    chmod +x ~/Desktop/*.desktop
    echo -e "${G}✅ Browsers installed${N}"
}

start_services() {
    echo -e "${Y}▶ Starting Services...${N}"
    systemctl start xrdp
    vncserver -localhost no :1
    systemctl start novnc
    echo -e "${G}✅ Services Started${N}"
    sleep 1
}

stop_services() {
    echo -e "${Y}⏹ Stopping Services...${N}"
    systemctl stop xrdp novnc
    vncserver -kill :1 2>/dev/null || true
    echo -e "${G}✅ Services Stopped${N}"
    sleep 1
}

restart_services() {
    stop_services
    start_services
}

status_services() {
    echo -e "${C}════════════════════════════════════════════${N}"
    echo -e "${Y}🔍 Service Status:${N}"
    echo -e "${C}════════════════════════════════════════════${N}"
    systemctl is-active xrdp && echo -e "xRDP    : ${G}ACTIVE${N}" || echo -e "xRDP    : ${R}INACTIVE${N}"
    systemctl is-active novnc && echo -e "noVNC   : ${G}ACTIVE${N}" || echo -e "noVNC   : ${R}INACTIVE${N}"
    netstat -tulpn | grep -E ":3389|:6080|:5901" && echo -e "Ports   : ${G}LISTENING${N}" || echo -e "Ports   : ${R}NOT LISTENING${N}"
    echo -e "${C}════════════════════════════════════════════${N}"
    read -p "Press Enter to continue..."
}

change_vnc_password() {
    echo -e "${Y}🔐 Change VNC Password${N}"
    vncpasswd
    echo -e "${G}✅ Password changed. Restart VNC to apply.${N}"
    read -p "Press Enter..."
}

uninstall_all() {
    echo -e "${R}⚠️  WARNING: This will remove ALL RDP/VNC components${N}"
  
    
    echo -e "${R}🗑️  Removing everything...${N}"
    stop_services
    
    # Remove packages
    apt purge -y xfce4* xrdp tigervnc* novnc websockify \
        firefox-esr google-chrome-stable chromium brave-browser
    
    # Remove configs
    rm -rf ~/.vnc /etc/systemd/system/novnc.service
    rm -f ~/.xsession /etc/skel/.xsession
    
    # Clean up
    apt autoremove -y
    apt clean
    echo "🧨 Stopping services..."
    systemctl stop xrdp || true
    systemctl stop novnc || true
    echo "🧹 Removing xRDP..."
    apt purge -y xrdp
    rm -rf /etc/xrdp
    echo "🧹 Removing VNC..."
    vncserver -kill :1 || true
    apt purge -y tigervnc-standalone-server tigervnc-common
    rm -rf ~/.vnc

    echo "🧹 Removing noVNC..."
    apt purge -y novnc websockify
    rm -f /etc/systemd/system/novnc.service
    systemctl daemon-reload

    echo "🧹 Removing Browsers..."
    apt purge -y \
      google-chrome-stable \
      firefox firefox-esr \
      chromium chromium-browser \
      brave-browser
    echo "🧹 Removing browser repos & keys..."
    rm -f /etc/apt/sources.list.d/google-chrome.list
    rm -f /etc/apt/sources.list.d/brave-browser-release.list
    rm -f /usr/share/keyrings/google-chrome.gpg
    rm -f /usr/share/keyrings/brave-browser-archive-keyring.gpg
    echo "🧹 Removing Desktop icons..."
    rm -f ~/Desktop/*.desktop
    echo "🧹 Autoremove & cleanup..."
    apt autoremove -y
    apt autoclean -y
    echo "✅ DONE!"
    echo "System cleaned: xRDP • Browsers • VNC • noVNC removed"
    systemctl daemon-reload
    
    echo -e "${G}✅ Uninstall complete${N}"
    read -p "Press Enter..."
}
# Main menu
while true; do
    header
    show_info
    
    echo -e "${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
    echo -e "${G}1) ${W}Install RDP + noVNC + Browsers${N}"
    echo -e "${G}2) ${W}Start Services${N}"
    echo -e "${G}3) ${W}Stop Services${N}"
    echo -e "${G}4) ${W}Restart Services${N}"
    echo -e "${G}5) ${W}Check Status${N}"
    echo -e "${G}6) ${W}Change VNC Password${N}"
    echo -e "${G}7) ${W}Install Browsers Only${N}"
    echo -e "${G}7) ${W}User  Only${N}"
    echo -e "${R}8) ${W}Uninstall Everything${N}"
    echo -e "${R}0) ${W}Exit${N}"
    echo -e "${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
    
    read -p "Select option: " opt
    
    case $opt in
        1) install_all ;;
        2) start_services ;;
        3) stop_services ;;
        4) restart_services ;;
        5) status_services ;;
        6) change_vnc_password ;;
        7) install_browsers ;;
        8)
           # 4️⃣ Set root password = root
           echo -e "root\nroot" | passwd root
           # 5️⃣ Allow root login in XRDP
           sed -i 's/^AllowRootLogin=false/AllowRootLogin=true/' /etc/xrdp/sesman.ini || true

           # 6️⃣ Allow root in PAM
           sed -i 's/^auth required pam_succeed_if.so user != root quiet_success/#&/' /etc/pam.d/xrdp-sesman || true

           # 7️⃣ Set XFCE session for root
           echo "startxfce4" > /root/.xsession
           chmod +x /root/.xsession

           # 8️⃣ Fix permissions
           adduser xrdp ssl-cert || true

           # 9️⃣ Restart XRDP
           systemctl restart xrdp

           echo "✅ DONE!"
           echo "=============================="
           echo "XRDP LOGIN DETAILS:"
           echo "IP       : YOUR_VPS_IP"
           echo "USERNAME : root"
           echo "PASSWORD : root"
           echo "SESSION  : Xorg"
           echo "=============================="
           ;;

        9) uninstall_all ;;
        0) echo -e "${G}Goodbye!${N}"; exit 0 ;;
        *) echo -e "${R}Invalid option${N}"; sleep 1 ;;
    esac
done
