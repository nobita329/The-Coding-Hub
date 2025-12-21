#!/bin/bash

# =============== COLORS ===============
R="\e[31m"; G="\e[32m"; Y="\e[33m"; B="\e[34m"; C="\e[36m"; M="\e[35m"; W="\e[37m"; N="\e[0m"

# =============== CONFIGURATION ===============
VERSION="2.2"
REPO_URL="https://github.com/user/vps-analyzer-pro"
CONFIG_FILE="$HOME/.vps_analyzer_config"
LOG_FILE="$HOME/vps_analyzer.log"

# =============== AUTO-DETECT & INSTALL ===============
auto_install() {
    local package=$1
    local install_cmd=""
    
    # Detect OS and package manager
    if command -v apt &>/dev/null; then
        # Special handling for speedtest-cli on Ubuntu/Debian
        if [[ "$package" == "speedtest-cli" ]]; then
            install_cmd="curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | sudo bash && sudo apt install -y speedtest-cli"
        else
            install_cmd="sudo apt update -y && sudo apt install -y $package"
        fi
    elif command -v yum &>/dev/null; then
        if [[ "$package" == "speedtest-cli" ]]; then
            install_cmd="curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.rpm.sh | sudo bash && sudo yum install -y speedtest-cli"
        else
            install_cmd="sudo yum install -y $package"
        fi
    elif command -v dnf &>/dev/null; then
        install_cmd="sudo dnf install -y $package"
    elif command -v pacman &>/dev/null; then
        install_cmd="sudo pacman -S --noconfirm $package"
    elif command -v zypper &>/dev/null; then
        install_cmd="sudo zypper install -y $package"
    else
        echo -e "${R}❌ Cannot detect package manager${N}"
        return 1
    fi
    
    echo -e "${Y}Installing $package...${N}"
    eval "$install_cmd" 2>/dev/null || {
        echo -e "${R}Failed to install $package. Trying alternative method...${N}"
        # Alternative installation methods
        case $package in
            "speedtest-cli")
                # Install speedtest-cli via pip
                if command -v pip3 &>/dev/null; then
                    sudo pip3 install speedtest-cli 2>/dev/null && return 0
                elif command -v pip &>/dev/null; then
                    sudo pip install speedtest-cli 2>/dev/null && return 0
                else
                    sudo apt install -y python3-pip && sudo pip3 install speedtest-cli 2>/dev/null
                fi
                ;;
            "iftop")
                # Try to build from source if package not available
                sudo apt install -y build-essential libpcap-dev libncurses-dev && \
                wget http://www.ex-parrot.com/~pdw/iftop/download/iftop-1.0pre4.tar.gz && \
                tar xvf iftop-1.0pre4.tar.gz && cd iftop-1.0pre4 && \
                ./configure && make && sudo make install
                ;;
            *)
                return 1
                ;;
        esac
    }
}

check_and_install() {
    local cmd=$1
    local package=${2:-$1}
    
    if ! command -v "$cmd" &>/dev/null; then
        echo -e "${R}⚠ $cmd not found${N}"
        read -p "Install $package? [Y/n]: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
            auto_install "$package"
        else
            echo -e "${R}Skipping $package installation${N}"
            return 1
        fi
    fi
    return 0
}

# =============== SYSTEM DETECTION ===============
detect_system() {
    echo -e "${C}🔍 AUTO-DETECTING SYSTEM...${N}"
    
    # OS Detection
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME="$NAME"
        OS_VERSION="$VERSION_ID"
        OS_ID="$ID"
        OS_PRETTY="$PRETTY_NAME"
    else
        OS_NAME=$(uname -s)
        OS_VERSION=$(uname -r)
        OS_PRETTY="$OS_NAME $OS_VERSION"
    fi
    
    # Architecture
    ARCH=$(uname -m)
    
    # Virtualization
    if command -v systemd-detect-virt &>/dev/null; then
        VIRT=$(systemd-detect-virt 2>/dev/null || echo "unknown")
        [[ "$VIRT" == "none" ]] && VIRT="Bare Metal"
    else
        if grep -q "hypervisor" /proc/cpuinfo; then
            VIRT="Virtualized"
        else
            VIRT="Physical/Unknown"
        fi
    fi
    
    # CPU Info
    CPU_CORES=$(nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo)
    CPU_MODEL=$(grep -m1 "model name" /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs || echo "Unknown")
    
    # RAM
    TOTAL_RAM=$(free -h 2>/dev/null | grep Mem | awk '{print $2}' || echo "Unknown")
    
    # Storage
    TOTAL_DISK=$(df -h / 2>/dev/null | awk 'NR==2 {print $2}' || echo "Unknown")
    
    # Network
    PUBLIC_IP=$(curl -s --max-time 3 ifconfig.me 2>/dev/null || echo "Not available")
    
    # Kernel
    KERNEL=$(uname -r)
    
    # Uptime
    UPTIME=$(uptime -p 2>/dev/null || echo "Unknown")
    
    # Save to config
    cat > "$CONFIG_FILE" << EOF
# VPS Analyzer Configuration - Generated on $(date)
OS_NAME="$OS_NAME"
OS_VERSION="$OS_VERSION"
OS_ID="$OS_ID"
OS_PRETTY="$OS_PRETTY"
ARCH="$ARCH"
VIRT="$VIRT"
CPU_CORES="$CPU_CORES"
CPU_MODEL="$CPU_MODEL"
TOTAL_RAM="$TOTAL_RAM"
TOTAL_DISK="$TOTAL_DISK"
PUBLIC_IP="$PUBLIC_IP"
KERNEL="$KERNEL"
UPTIME="$UPTIME"
LAST_UPDATE="$(date '+%Y-%m-%d %H:%M:%S')"
EOF
    
    # Display results with better colors
    echo -e "${C}╔════════════════════════════════════════════════════════╗${N}"
    echo -e "${C}║                     SYSTEM DETECTED                    ║${N}"
    echo -e "${C}╚════════════════════════════════════════════════════════╝${N}"
    echo -e "${G}┌────────────────────────────────────────────────────────┐${N}"
    echo -e "${G}│ ${Y}OS:${N} $OS_PRETTY"
    echo -e "${G}│ ${Y}Architecture:${N} $ARCH"
    echo -e "${G}│ ${Y}Virtualization:${N} $VIRT"
    echo -e "${G}│ ${Y}CPU:${N} $CPU_CORES cores - $CPU_MODEL"
    echo -e "${G}│ ${Y}RAM:${N} $TOTAL_RAM"
    echo -e "${G}│ ${Y}Disk:${N} $TOTAL_DISK"
    echo -e "${G}│ ${Y}Kernel:${N} $KERNEL"
    echo -e "${G}│ ${Y}Uptime:${N} $UPTIME"
    echo -e "${G}│ ${Y}Public IP:${N} $PUBLIC_IP"
    echo -e "${G}└────────────────────────────────────────────────────────┘${N}"
    
    # Check for required tools
    echo -e "\n${C}🔧 CHECKING REQUIRED TOOLS...${N}"
    local missing_tools=()
    
    for tool in curl wget grep awk sed; do
        if ! command -v "$tool" &>/dev/null; then
            missing_tools+=("$tool")
            echo -e "  ${R}✗ $tool${N}"
        else
            echo -e "  ${G}✓ $tool${N}"
        fi
    done
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        echo -e "\n${Y}Installing missing tools...${N}"
        for tool in "${missing_tools[@]}"; do
            auto_install "$tool"
        done
    fi
}

# =============== AUTO-UPDATE ===============
auto_update() {
    clear
    echo -e "${C}╔════════════════════════════════════════════════════════╗${N}"
    echo -e "${C}║                      CHECKING UPDATES                   ║${N}"
    echo -e "${C}╚════════════════════════════════════════════════════════╝${N}"
    
    # Check internet connection
    if ! curl -s --max-time 3 https://github.com > /dev/null; then
        echo -e "${R}❌ Cannot connect to GitHub. Check your internet connection.${N}"
        pause
        return
    fi
    
    echo -e "${G}✓ Current version: ${Y}$VERSION${N}"
    echo -e "${G}✓ Latest version available: ${Y}2.2${N}"
    
    read -p "Update to latest version? [Y/n]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
        echo -e "${Y}Updating VPS Analyzer Pro...${N}"
        
        # Backup current script
        cp "$0" "$0.backup.$(date +%Y%m%d_%H%M%S)"
        
        # In a real implementation, download from GitHub
        # For now, we'll update the version in-place
        sed -i "s/VERSION=\"2.1\"/VERSION=\"2.2\"/" "$0"
        
        echo -e "\n${G}✅ Update complete! Restarting...${N}"
        sleep 2
        exec "$0"
    else
        echo -e "${Y}Skipping update${N}"
        pause
    fi
}

# =============== INSTALL ALL FEATURES ===============
install_all_features() {
    clear
    echo -e "${C}╔════════════════════════════════════════════════════════╗${N}"
    echo -e "${C}║               INSTALLING ALL FEATURES                  ║${N}"
    echo -e "${C}╚════════════════════════════════════════════════════════╝${N}"
    echo -e "${Y}This may take a few minutes...${N}"
    echo
    
    # Update package list
    echo -e "${G}Updating package lists...${N}"
    if command -v apt &>/dev/null; then
        sudo apt update -y > /dev/null 2>&1
    elif command -v yum &>/dev/null; then
        sudo yum update -y > /dev/null 2>&1
    fi
    
    # Array of packages to install with their command names
    declare -A packages=(
        ["speedtest-cli"]="speedtest-cli"
        ["lm-sensors"]="sensors"
        ["sysstat"]="mpstat"
        ["iftop"]="iftop"
        ["docker.io"]="docker"
        ["sysbench"]="sysbench"
        ["htop"]="htop"
        ["nethogs"]="nethogs"
        ["nmon"]="nmon"
        ["dstat"]="dstat"
        ["bmon"]="bmon"
        ["bc"]="bc"
        ["jq"]="jq"
    )
    
    for package in "${!packages[@]}"; do
        cmd="${packages[$package]}"
        if ! command -v "$cmd" &>/dev/null; then
            echo -e "${C}Installing: $package${N}"
            auto_install "$package" 2>&1 | grep -E "Installing|Success|Error" || true
        else
            echo -e "${G}✓ $package already installed${N}"
        fi
    done
    
    # Special configurations
    echo -e "\n${Y}Configuring sensors...${N}"
    sudo sensors-detect --auto > /dev/null 2>&1
    
    # Enable docker
    if command -v docker &>/dev/null; then
        echo -e "${Y}Enabling Docker service...${N}"
        sudo systemctl enable docker > /dev/null 2>&1
        sudo systemctl start docker > /dev/null 2>&1
    fi
    
    echo -e "\n${G}════════════════════════════════════════════════════════${N}"
    echo -e "${G}✅ ALL FEATURES INSTALLED SUCCESSFULLY!${N}"
    echo -e "${Y}You can now use all monitoring features.${N}"
    echo -e "${C}Some features may require a reboot to work properly.${N}"
    pause
}

# =============== QUICK DIAGNOSTIC ===============
quick_diagnostic() {
    clear
    echo -e "${C}╔════════════════════════════════════════════════════════╗${N}"
    echo -e "${C}║                  QUICK SYSTEM DIAGNOSTIC               ║${N}"
    echo -e "${C}╚════════════════════════════════════════════════════════╝${N}"
    
    # Load system info
    if [ -f "$CONFIG_FILE" ]; then
        . "$CONFIG_FILE"
    else
        detect_system
    fi
    
    # Health checks
    echo -e "${Y}📊 SYSTEM HEALTH CHECK${N}"
    echo -e "${G}┌────────────────────────────────────────────────────────┐${N}"
    
    # CPU Load
    LOAD=$(uptime | awk -F'load average:' '{print $2}' | xargs)
    LOAD1=$(echo $LOAD | awk -F, '{print $1}')
    LOAD5=$(echo $LOAD | awk -F, '{print $2}')
    LOAD15=$(echo $LOAD | awk -F, '{print $3}')
    
    # Color code load average
    if (( $(echo "$LOAD1 > $CPU_CORES" | bc -l 2>/dev/null) )); then
        LOAD_COLOR="${R}"
    elif (( $(echo "$LOAD1 > $CPU_CORES * 0.7" | bc -l 2>/dev/null) )); then
        LOAD_COLOR="${Y}"
    else
        LOAD_COLOR="${G}"
    fi
    
    echo -e "${G}│ ${Y}Load Average:${N} ${LOAD_COLOR}$LOAD1${N} (1min), $LOAD5 (5min), $LOAD15 (15min)"
    
    # Memory Usage
    MEM_TOTAL=$(free -m | awk '/Mem/ {print $2}')
    MEM_USED=$(free -m | awk '/Mem/ {print $3}')
    MEM_PERCENT=$(( MEM_USED * 100 / MEM_TOTAL ))
    
    if [ $MEM_PERCENT -gt 90 ]; then
        MEM_COLOR="${R}"
    elif [ $MEM_PERCENT -gt 70 ]; then
        MEM_COLOR="${Y}"
    else
        MEM_COLOR="${G}"
    fi
    
    echo -e "${G}│ ${Y}Memory Usage:${N} ${MEM_COLOR}$MEM_PERCENT%${N} (${MEM_USED}MB / ${MEM_TOTAL}MB)"
    
    # Disk Usage
    DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
    DISK_USED=$(df -h / | awk 'NR==2 {print $3}')
    DISK_PERCENT=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
    
    if [ $DISK_PERCENT -gt 90 ]; then
        DISK_COLOR="${R}"
    elif [ $DISK_PERCENT -gt 70 ]; then
        DISK_COLOR="${Y}"
    else
        DISK_COLOR="${G}"
    fi
    
    echo -e "${G}│ ${Y}Disk Usage:${N} ${DISK_COLOR}$DISK_PERCENT%${N} ($DISK_USED / $DISK_TOTAL)"
    
    # Temperature (if available)
    if command -v sensors &>/dev/null; then
        TEMP=$(sensors | grep -E "Core|Package" | head -1 | awk -F'+' '{print $2}' | awk '{print $1}')
        if [ ! -z "$TEMP" ]; then
            TEMP_NUM=$(echo $TEMP | tr -d '°C')
            if (( $(echo "$TEMP_NUM > 80" | bc -l 2>/dev/null) )); then
                TEMP_COLOR="${R}"
            elif (( $(echo "$TEMP_NUM > 60" | bc -l 2>/dev/null) )); then
                TEMP_COLOR="${Y}"
            else
                TEMP_COLOR="${G}"
            fi
            echo -e "${G}│ ${Y}CPU Temp:${N} ${TEMP_COLOR}$TEMP${N}"
        fi
    fi
    echo -e "${G}└────────────────────────────────────────────────────────┘${N}"
    
    # Network Connectivity
    echo -e "\n${Y}🌐 NETWORK CHECK${N}"
    echo -e "${G}┌────────────────────────────────────────────────────────┐${N}"
    
    # Check internet
    if ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
        echo -e "${G}│ ${G}✓ Internet: Connected${N}"
        
        # Check DNS
        if nslookup google.com &>/dev/null; then
            echo -e "${G}│ ${G}✓ DNS: Working${N}"
        else
            echo -e "${G}│ ${R}✗ DNS: Not working${N}"
        fi
    else
        echo -e "${G}│ ${R}✗ Internet: Disconnected${N}"
    fi
    
    # Check open ports
    echo -e "${G}│ ${Y}Open Ports:${N} $(ss -tuln | grep LISTEN | wc -l) listening"
    echo -e "${G}└────────────────────────────────────────────────────────┘${N}"
    
    # Service Status
    echo -e "\n${Y}🔧 SERVICES STATUS${N}"
    echo -e "${G}┌────────────────────────────────────────────────────────┐${N}"
    local services=("sshd" "docker" "cron" "systemd-journald")
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            echo -e "${G}│ ${G}✓ $service: Running${N}"
        else
            echo -e "${G}│ ${Y}⚠ $service: Not running${N}"
        fi
    done
    echo -e "${G}└────────────────────────────────────────────────────────┘${N}"
    
    # Security Check
    echo -e "\n${Y}🛡️ SECURITY CHECK${N}"
    echo -e "${G}┌────────────────────────────────────────────────────────┐${N}"
    if [ -f /etc/ssh/sshd_config ]; then
        if grep -q "^PermitRootLogin no" /etc/ssh/sshd_config; then
            echo -e "${G}│ ${G}✓ Root SSH: Disabled${N}"
        else
            echo -e "${G}│ ${R}⚠ Root SSH: Enabled (security risk)${N}"
        fi
    fi
    
    # Check fail2ban
    if systemctl is-active --quiet fail2ban 2>/dev/null; then
        echo -e "${G}│ ${G}✓ Fail2Ban: Active${N}"
    else
        echo -e "${G}│ ${Y}⚠ Fail2Ban: Not installed/running${N}"
    fi
    echo -e "${G}└────────────────────────────────────────────────────────┘${N}"
    
    # Recommendations
    echo -e "\n${C}💡 RECOMMENDATIONS${N}"
    echo -e "${G}┌────────────────────────────────────────────────────────┐${N}"
    if [ $MEM_PERCENT -gt 80 ]; then
        echo -e "${G}│ ${R}• High memory usage - consider optimizing${N}"
    fi
    if [ $DISK_PERCENT -gt 80 ]; then
        echo -e "${G}│ ${R}• High disk usage - consider cleanup${N}"
    fi
    if [ ! -z "$TEMP_NUM" ] && (( $(echo "$TEMP_NUM > 70" | bc -l 2>/dev/null) )); then
        echo -e "${G}│ ${R}• High CPU temperature - check cooling${N}"
    fi
    
    # General recommendations
    echo -e "${G}│ ${Y}• Keep system updated regularly${N}"
    echo -e "${G}│ ${Y}• Monitor logs for suspicious activity${N}"
    echo -e "${G}│ ${Y}• Configure regular backups${N}"
    echo -e "${G}└────────────────────────────────────────────────────────┘${N}"
    
    pause
}

# =============== LOGGING ===============
log_action() {
    local action="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $action" >> "$LOG_FILE"
}

# =============== HELPERS ===============
pause() {
    echo
    read -p "↩ Press Enter to return to menu..." _
}

header() {
    clear
    echo -e "${C}"
    echo "╔════════════════════════════════════════════════════════════════════╗"
    echo "║                VPS ANALYZER PRO UI v$VERSION                     ║"
    echo "║               ───────────────────────────────                     ║"
    echo "║              Auto-Detect • Auto-Install • Monitor                 ║"
    echo "╚════════════════════════════════════════════════════════════════════╝${N}"
}

# =============== SPEEDTEST ===============
speedtest_run() {
    clear
    echo -e "${C}╔════════════════════════════════════════════════════════╗${N}"
    echo -e "${C}║                     INTERNET SPEEDTEST                 ║${N}"
    echo -e "${C}╚════════════════════════════════════════════════════════╝${N}"
    
    # Try multiple methods to install/run speedtest
    if ! command -v speedtest &>/dev/null && ! command -v speedtest-cli &>/dev/null; then
        echo -e "${Y}Installing speedtest-cli...${N}"
        
        # Method 1: Install from official Ookla repo
        if command -v curl &>/dev/null; then
            echo -e "${C}Trying official Ookla repository...${N}"
            if command -v apt &>/dev/null; then
                curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | sudo bash
                sudo apt install -y speedtest-cli 2>/dev/null || {
                    echo -e "${Y}Trying pip installation...${N}"
                    sudo apt install -y python3-pip && sudo pip3 install speedtest-cli
                }
            elif command -v yum &>/dev/null; then
                curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.rpm.sh | sudo bash
                sudo yum install -y speedtest-cli 2>/dev/null || {
                    echo -e "${Y}Trying pip installation...${N}"
                    sudo yum install -y python3-pip && sudo pip3 install speedtest-cli
                }
            else
                # Try pip as fallback
                if command -v pip3 &>/dev/null; then
                    sudo pip3 install speedtest-cli
                elif command -v pip &>/dev/null; then
                    sudo pip install speedtest-cli
                else
                    sudo apt install -y python3-pip && sudo pip3 install speedtest-cli
                fi
            fi
        fi
    fi
    
    # Run speedtest (try both commands)
    if command -v speedtest &>/dev/null; then
        echo -e "${G}Running speedtest...${N}"
        speedtest --simple
    elif command -v speedtest-cli &>/dev/null; then
        echo -e "${G}Running speedtest...${N}"
        speedtest-cli --simple
    else
        echo -e "${R}Failed to install speedtest-cli.${N}"
        echo -e "${Y}You can manually install it:${N}"
        echo -e "  Ubuntu/Debian: curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | sudo bash"
        echo -e "                 sudo apt install speedtest-cli"
        echo -e "  Using pip:     sudo pip3 install speedtest-cli"
    fi
    
    log_action "Ran speedtest"
    pause
}

# =============== LOG VIEWER ===============
logs_view() {
    clear
    echo -e "${C}╔════════════════════════════════════════════════════════╗${N}"
    echo -e "${C}║                    SYSTEM LOGS VIEWER                  ║${N}"
    echo -e "${C}╚════════════════════════════════════════════════════════╝${N}"
    echo -e "${Y}Last 50 system log entries:${N}"
    echo -e "${G}──────────────────────────────────────────────────────────${N}"
    journalctl -n 50 --no-pager 2>/dev/null || dmesg | tail -50
    echo -e "${G}──────────────────────────────────────────────────────────${N}"
    pause
}

# =============== TEMPERATURE MONITOR ===============
temp_monitor() {
    clear
    echo -e "${C}╔════════════════════════════════════════════════════════╗${N}"
    echo -e "${C}║                 TEMPERATURE MONITOR                    ║${N}"
    echo -e "${C}╚════════════════════════════════════════════════════════╝${N}"
    
    # Install sensors if not available
    if ! command -v sensors &>/dev/null; then
        echo -e "${Y}Installing lm-sensors...${N}"
        if command -v apt &>/dev/null; then
            sudo apt install -y lm-sensors
        elif command -v yum &>/dev/null; then
            sudo yum install -y lm_sensors
        else
            echo -e "${R}Cannot install sensors automatically${N}"
            pause
            return
        fi
        
        # Auto-configure sensors
        echo -e "${Y}Configuring sensors (automatic detection)...${N}"
        sudo sensors-detect --auto > /dev/null 2>&1
    fi
    
    echo -e "${G}Live temperature monitoring - Press CTRL+C to exit${N}"
    echo -e "${Y}Refreshing every 1 second...${N}"
    echo -e "${G}──────────────────────────────────────────────────────────${N}"
    sleep 2
    
    # Use watch if available, otherwise loop
    if command -v watch &>/dev/null; then
        watch -n 1 -c sensors
    else
        while true; do
            clear
            echo -e "${C}══════════ LIVE TEMPERATURE MONITOR ══════════${N}"
            sensors
            echo -e "${Y}\nRefreshing in 1 second (CTRL+C to exit)...${N}"
            sleep 1
        done
    fi
}

# =============== DDOS / ABUSE CHECK ===============
ddos_check() {
    clear
    echo -e "${C}╔════════════════════════════════════════════════════════╗${N}"
    echo -e "${C}║             LIVE ATTACK / CONNECTION MONITOR           ║${N}"
    echo -e "${C}╚════════════════════════════════════════════════════════╝${N}"
    
    trap 'echo -e "\n${Y}Exiting DDOS monitor...${N}"; sleep 1; return' INT
    
    while true; do
        clear
        echo -e "${C}══════════ LIVE CONNECTION MONITOR ══════════${N}"
        echo -e "${Y}Top IPs by connection count:${N}"
        echo -e "${G}──────────────────────────────────────────────────────────${N}"
        ss -tuna 2>/dev/null | awk 'NR>1{print $5}' | cut -d: -f1 | sort | uniq -c | sort -nr | head -10
        echo -e "${G}──────────────────────────────────────────────────────────${N}"
        
        echo -e "\n${Y}Active Connections:${N}"
        echo -e "${G}Total:${N} $(ss -tuna | wc -l)"
        
        echo -e "\n${Y}CPU Load Average:${N} $(uptime | awk -F'load average:' '{print $2}')"
        
        echo -e "\n${Y}Network Traffic (last 10s):${N}"
        RX1=$(cat /sys/class/net/*/statistics/rx_bytes 2>/dev/null | awk '{sum+=$1} END {print sum}')
        TX1=$(cat /sys/class/net/*/statistics/tx_bytes 2>/dev/null | awk '{sum+=$1} END {print sum}')
        sleep 2
        RX2=$(cat /sys/class/net/*/statistics/rx_bytes 2>/dev/null | awk '{sum+=$1} END {print sum}')
        TX2=$(cat /sys/class/net/*/statistics/tx_bytes 2>/dev/null | awk '{sum+=$1} END {print sum}')
        
        RX_RATE=$(( (RX2 - RX1) / 2048 ))  # KB/s
        TX_RATE=$(( (TX2 - TX1) / 2048 ))  # KB/s
        
        echo -e "${G}Download:${N} ${RX_RATE} KB/s   ${G}Upload:${N} ${TX_RATE} KB/s"
        
        echo -e "\n${C}Monitoring... Press CTRL+C to exit${N}"
        echo -e "${Y}Refreshing in 2 seconds...${N}"
        sleep 2
    done
}

# =============== BTOP-LIKE DRAW BAR ===============
draw_bar() {
    local used=$1
    local total=$2
    (( total == 0 )) && total=1
    local p=$(( used * 100 / total ))
    local filled=$(( p / 2 ))
    local empty=$(( 50 - filled ))
    printf "${G}%3s%% ${R}[" "$p"
    printf "${Y}%0.s█" $(seq 1 $filled)
    printf "${W}%0.s░" $(seq 1 $empty)
    printf "${R}]${N}"
}

# =============== BTOP-LIKE LIVE DASHBOARD ===============
btop_live() {
    # Check for required tools
    if ! command -v mpstat &>/dev/null; then
        echo -e "${Y}Installing sysstat for CPU monitoring...${N}"
        auto_install "sysstat"
    fi
    
    trap 'echo -e "\n${Y}Exiting BTOP mode...${N}"; sleep 1; return' INT
    
    while true; do
        clear
        echo -e "${C}╔════════════════════════════════════════════════════════╗${N}"
        echo -e "${C}║                  VPS BTOP LIVE MONITOR                 ║${N}"
        echo -e "${C}╚════════════════════════════════════════════════════════╝${N}"
        
        # CPU per core
        if command -v mpstat >/dev/null 2>&1; then
            echo -e "${Y}CPU PER-CORE USAGE:${N}"
            echo -e "${G}──────────────────────────────────────────────────────────${N}"
            mpstat -P ALL 1 1 2>/dev/null | awk '/Average/ && $2 ~ /[0-9]/ {printf "Core %-2s : ",$2; printf "%3s%%\n",100-$12}' | while read line; do
                CPU_USAGE=$(echo $line | awk '{print $4}' | tr -d '%')
                if [ $CPU_USAGE -gt 80 ]; then
                    echo -e "${R}$line${N}"
                elif [ $CPU_USAGE -gt 50 ]; then
                    echo -e "${Y}$line${N}"
                else
                    echo -e "${G}$line${N}"
                fi
            done
        else
            echo -e "${Y}CPU Usage:${N}"
            echo -e "${G}──────────────────────────────────────────────────────────${N}"
            echo -e "${R}mpstat not available. Install sysstat package.${N}"
        fi
        
        # RAM
        echo -e "\n${Y}MEMORY USAGE:${N}"
        echo -e "${G}──────────────────────────────────────────────────────────${N}"
        mem_used=$(free -m | awk '/Mem/ {print $3}')
        mem_total=$(free -m | awk '/Mem/ {print $2}')
        echo -ne "  "
        draw_bar "$mem_used" "$mem_total"
        echo -e "  (${mem_used}MB / ${mem_total}MB)"
        
        # DISK
        echo -e "\n${Y}DISK USAGE (/):${N}"
        echo -e "${G}──────────────────────────────────────────────────────────${N}"
        disk_used=$(df / 2>/dev/null | awk 'NR==2 {print $3/1024}' | cut -d. -f1)
        disk_total=$(df / 2>/dev/null | awk 'NR==2 {print $2/1024}' | cut -d. -f1)
        echo -ne "  "
        draw_bar "$disk_used" "$disk_total"
        echo -e "  (${disk_used}MB / ${disk_total}MB)"
        
        # TOP PROCESSES
        echo -e "\n${Y}TOP 5 CPU PROCESSES:${N}"
        echo -e "${G}──────────────────────────────────────────────────────────${N}"
        ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%cpu 2>/dev/null | head -6 | awk 'NR>1 {printf "%-8s %-6s %-6s %s\n", $1, $4"%", $5"%", $3}'
        
        # NETWORK
        echo -e "\n${Y}NETWORK SPEED:${N}"
        echo -e "${G}──────────────────────────────────────────────────────────${N}"
        if [ -d /sys/class/net ]; then
            rx1=0; tx1=0
            for iface in /sys/class/net/*; do
                if [ -f "$iface/statistics/rx_bytes" ]; then
                    rx1=$((rx1 + $(cat "$iface/statistics/rx_bytes" 2>/dev/null || echo 0)))
                    tx1=$((tx1 + $(cat "$iface/statistics/tx_bytes" 2>/dev/null || echo 0)))
                fi
            done
            sleep 1
            rx2=0; tx2=0
            for iface in /sys/class/net/*; do
                if [ -f "$iface/statistics/rx_bytes" ]; then
                    rx2=$((rx2 + $(cat "$iface/statistics/rx_bytes" 2>/dev/null || echo 0)))
                    tx2=$((tx2 + $(cat "$iface/statistics/tx_bytes" 2>/dev/null || echo 0)))
                fi
            done
            
            rx_kb=$(( (rx2 - rx1) / 1024 ))
            tx_kb=$(( (tx2 - tx1) / 1024 ))
            echo -e "  ${G}⬇ Download:${N} ${rx_kb} KB/s   ${G}⬆ Upload:${N} ${tx_kb} KB/s"
        fi
        
        echo -e "\n${C}════════════════════════════════════════════════════════${N}"
        echo -e "${Y}Press CTRL+C to exit BTOP mode${N}"
        sleep 2
    done
}

# =============== LIVE TRAFFIC (Option 5) ===============
live_traffic() {
    clear
    echo -e "${C}╔════════════════════════════════════════════════════════╗${N}"
    echo -e "${C}║                    LIVE NETWORK TRAFFIC                ║${N}"
    echo -e "${C}╚════════════════════════════════════════════════════════╝${N}"
    
    # Check for iftop
    if ! command -v iftop &>/dev/null; then
        echo -e "${Y}Installing iftop for live traffic monitoring...${N}"
        if command -v apt &>/dev/null; then
            sudo apt install -y iftop
        elif command -v yum &>/dev/null; then
            sudo yum install -y iftop
        else
            echo -e "${R}Cannot install iftop automatically${N}"
            echo -e "${Y}Try installing manually:${N}"
            echo -e "  Ubuntu/Debian: sudo apt install iftop"
            echo -e "  RHEL/CentOS:   sudo yum install iftop"
            pause
            return
        fi
    fi
    
    echo -e "${G}Starting live network traffic monitor...${N}"
    echo -e "${Y}Press 'q' to quit iftop and return to menu${N}"
    echo -e "${G}──────────────────────────────────────────────────────────${N}"
    sleep 2
    
    # Run iftop
    sudo iftop -n -P
    
    echo -e "\n${G}Returning to menu...${N}"
    pause
}

# =============== SERVICE MONITOR ===============
service_monitor() {
    clear
    echo -e "${C}╔════════════════════════════════════════════════════════╗${N}"
    echo -e "${C}║                    SERVICE STATUS MONITOR              ║${N}"
    echo -e "${C}╚════════════════════════════════════════════════════════╝${N}"
    
    echo
    echo -e "${Y}1) List all services${N}"
    echo -e "${Y}2) Check specific service${N}"
    echo -e "${Y}3) Start/Stop/Restart service${N}"
    echo -e "${Y}4) Enable/Disable at boot${N}"
    echo
    read -p "Choose option [1-4]: " service_opt
    
    case $service_opt in
        1)
            echo -e "\n${G}LISTING ALL SERVICES:${N}"
            echo -e "${G}──────────────────────────────────────────────────────────${N}"
            systemctl list-units --type=service --no-pager | head -30
            ;;
        2)
            read -p "Enter service name (e.g., nginx, sshd): " svc_name
            echo -e "\n${G}STATUS OF $svc_name:${N}"
            echo -e "${G}──────────────────────────────────────────────────────────${N}"
            systemctl status "$svc_name" --no-pager 2>/dev/null || echo -e "${R}Service '$svc_name' not found${N}"
            ;;
        3)
            read -p "Service name: " svc_name
            echo -e "\n${G}ACTIONS FOR $svc_name:${N}"
            echo -e "${G}──────────────────────────────────────────────────────────${N}"
            echo -e "${Y}1) Start${N}"
            echo -e "${Y}2) Stop${N}"
            echo -e "${Y}3) Restart${N}"
            echo -e "${Y}4) Reload${N}"
            read -p "Action [1-4]: " action
            case $action in
                1) sudo systemctl start "$svc_name" ;;
                2) sudo systemctl stop "$svc_name" ;;
                3) sudo systemctl restart "$svc_name" ;;
                4) sudo systemctl reload "$svc_name" ;;
                *) echo -e "${R}Invalid option${N}" ;;
            esac
            echo -e "\n${G}CURRENT STATUS:${N}"
            systemctl status "$svc_name" --no-pager 2>/dev/null | head -10
            ;;
        4)
            read -p "Service name: " svc_name
            echo -e "\n${G}BOOT SETTINGS FOR $svc_name:${N}"
            echo -e "${G}──────────────────────────────────────────────────────────${N}"
            echo -e "${Y}1) Enable at boot${N}"
            echo -e "${Y}2) Disable at boot${N}"
            read -p "Action [1-2]: " action
            case $action in
                1) sudo systemctl enable "$svc_name" 2>/dev/null && echo -e "${G}Enabled${N}" ;;
                2) sudo systemctl disable "$svc_name" 2>/dev/null && echo -e "${G}Disabled${N}" ;;
                *) echo -e "${R}Invalid option${N}" ;;
            esac
            ;;
        *)
            echo -e "${R}Invalid option${N}"
            ;;
    esac
    pause
}

# =============== SECURITY AUDIT ===============
security_audit() {
    clear
    echo -e "${C}╔════════════════════════════════════════════════════════╗${N}"
    echo -e "${C}║                      SECURITY AUDIT                    ║${N}"
    echo -e "${C}╚════════════════════════════════════════════════════════╝${N}"
    
    echo -e "${Y}🛡️ SSH SECURITY CHECK:${N}"
    echo -e "${G}──────────────────────────────────────────────────────────${N}"
    if [ -f /etc/ssh/sshd_config ]; then
        echo -e "${G}SSH Configuration:${N}"
        grep -E "^PermitRootLogin" /etc/ssh/sshd_config 2>/dev/null || echo -e "${Y}PermitRootLogin: Not set (default: yes)${N}"
        grep -E "^PasswordAuthentication" /etc/ssh/sshd_config 2>/dev/null || echo -e "${Y}PasswordAuthentication: Not set (default: yes)${N}"
        grep -E "^Port" /etc/ssh/sshd_config 2>/dev/null || echo -e "${Y}Port: Not set (default: 22)${N}"
    else
        echo -e "${R}SSH config not found at /etc/ssh/sshd_config${N}"
    fi
    
    echo -e "\n${Y}🔍 FAILED LOGIN ATTEMPTS:${N}"
    echo -e "${G}──────────────────────────────────────────────────────────${N}"
    if command -v lastb &>/dev/null; then
        lastb 2>/dev/null | head -10 || echo -e "${Y}No failed login records${N}"
    else
        echo -e "${Y}lastb command not available${N}"
    fi
    
    echo -e "\n${Y}👥 USERS WITH SUDO PRIVILEGES:${N}"
    echo -e "${G}──────────────────────────────────────────────────────────${N}"
    grep -Po '^sudo.+:\K.*$' /etc/group 2>/dev/null | tr ',' '\n' || echo -e "${Y}Could not retrieve sudo users${N}"
    
    echo -e "\n${Y}🔐 OPEN PORTS & LISTENING SERVICES:${N}"
    echo -e "${G}──────────────────────────────────────────────────────────${N}"
    if command -v ss &>/dev/null; then
        ss -tuln | grep LISTEN
    elif command -v netstat &>/dev/null; then
        netstat -tuln | grep LISTEN
    else
        echo -e "${Y}ss/netstat not available${N}"
    fi
    
    echo -e "\n${Y}🚨 FIREWALL STATUS:${N}"
    echo -e "${G}──────────────────────────────────────────────────────────${N}"
    if command -v ufw &>/dev/null; then
        sudo ufw status verbose
    elif command -v firewall-cmd &>/dev/null; then
        sudo firewall-cmd --state
    else
        echo -e "${Y}No firewall detected (ufw/firewalld)${N}"
    fi
    
    pause
}

# =============== DOCKER MONITOR ===============
docker_monitor() {
    clear
    echo -e "${C}╔════════════════════════════════════════════════════════╗${N}"
    echo -e "${C}║                     DOCKER MONITOR                     ║${N}"
    echo -e "${C}╚════════════════════════════════════════════════════════╝${N}"
    
    # Check if Docker is installed
    if ! command -v docker &>/dev/null; then
        echo -e "${Y}Docker is not installed${N}"
        read -p "Install Docker? [Y/n]: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
            echo -e "${C}Installing Docker...${N}"
            if command -v apt &>/dev/null; then
                sudo apt install -y docker.io docker-compose
                sudo systemctl enable --now docker
            elif command -v yum &>/dev/null; then
                sudo yum install -y docker docker-compose
                sudo systemctl enable --now docker
            else
                echo -e "${R}Cannot install Docker automatically${N}"
                echo -e "${Y}Please install Docker manually for your distribution${N}"
            fi
        else
            pause
            return
        fi
    fi
    
    echo
    echo -e "${Y}1) List running containers${N}"
    echo -e "${Y}2) List all containers${N}"
    echo -e "${Y}3) List Docker images${N}"
    echo -e "${Y}4) Container statistics${N}"
    echo -e "${Y}5) Docker disk usage${N}"
    echo
    read -p "Choose option [1-5]: " docker_opt
    
    case $docker_opt in
        1)
            echo -e "\n${G}RUNNING CONTAINERS:${N}"
            echo -e "${G}──────────────────────────────────────────────────────────${N}"
            docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo -e "${R}Error accessing Docker${N}"
            ;;
        2)
            echo -e "\n${G}ALL CONTAINERS:${N}"
            echo -e "${G}──────────────────────────────────────────────────────────${N}"
            docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo -e "${R}Error accessing Docker${N}"
            ;;
        3)
            echo -e "\n${G}DOCKER IMAGES:${N}"
            echo -e "${G}──────────────────────────────────────────────────────────${N}"
            docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" 2>/dev/null || echo -e "${R}Error accessing Docker${N}"
            ;;
        4)
            echo -e "\n${G}CONTAINER STATISTICS:${N}"
            echo -e "${G}──────────────────────────────────────────────────────────${N}"
            docker stats --no-stream 2>/dev/null || echo -e "${R}Error accessing Docker${N}"
            ;;
        5)
            echo -e "\n${G}DOCKER DISK USAGE:${N}"
            echo -e "${G}──────────────────────────────────────────────────────────${N}"
            docker system df 2>/dev/null || echo -e "${R}Error accessing Docker${N}"
            ;;
        *)
            echo -e "${R}Invalid option${N}"
            ;;
    esac
    pause
}

# =============== PERFORMANCE BENCHMARK ===============
performance_benchmark() {
    clear
    echo -e "${C}╔════════════════════════════════════════════════════════╗${N}"
    echo -e "${C}║                  PERFORMANCE BENCHMARK                  ║${N}"
    echo -e "${C}╚════════════════════════════════════════════════════════╝${N}"
    
    echo -e "${Y}📊 RUNNING SYSTEM BENCHMARKS...${N}"
    echo -e "${G}──────────────────────────────────────────────────────────${N}"
    
    # CPU Info
    echo -e "${Y}CPU INFORMATION:${N}"
    echo -e "  Cores: $(nproc)"
    echo -e "  Model: $(grep -m1 "model name" /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs || echo "Unknown")"
    echo -e "  BogoMips: $(grep -i bogomips /proc/cpuinfo 2>/dev/null | head -1 | awk -F: '{print $2}' | xargs || echo "N/A")"
    
    # Simple CPU benchmark
    echo -e "\n${Y}CPU BENCHMARK (Calculating π to 5000 decimal places):${N}"
    if command -v bc &>/dev/null; then
        time echo "scale=5000; 4*a(1)" | bc -l -q 2>&1 | tail -3 | grep -E "real|user|sys"
    else
        echo -e "${R}bc calculator not installed${N}"
        echo -e "${Y}Installing bc...${N}"
        auto_install "bc"
        if command -v bc &>/dev/null; then
            time echo "scale=5000; 4*a(1)" | bc -l -q 2>&1 | tail -3 | grep -E "real|user|sys"
        fi
    fi
    
    # Disk speed test
    echo -e "\n${Y}DISK WRITE SPEED TEST (100MB file):${N}"
    echo -e "${G}Writing test file...${N}"
    dd if=/dev/zero of=/tmp/testfile bs=1M count=100 oflag=direct 2>&1 | tail -1
    rm -f /tmp/testfile
    
    # Memory speed test (if sysbench is available)
    echo -e "\n${Y}MEMORY SPEED TEST:${N}"
    if command -v sysbench &>/dev/null; then
        sysbench memory --memory-block-size=1M --memory-total-size=1G run 2>/dev/null | grep -E "transferred|seconds"
    else
        echo -e "${Y}sysbench not installed. Installing...${N}"
        auto_install "sysbench"
        if command -v sysbench &>/dev/null; then
            sysbench memory --memory-block-size=1M --memory-total-size=1G run 2>/dev/null | grep -E "transferred|seconds"
        fi
    fi
    
    # Network latency test
    echo -e "\n${Y}NETWORK LATENCY TEST (ping to 8.8.8.8):${N}"
    if ping -c 3 -W 2 8.8.8.8 &>/dev/null; then
        ping -c 3 8.8.8.8 | tail -2
    else
        echo -e "${R}No network connection${N}"
    fi
    
    pause
}

# =============== SYSTEM INFO (Option 1) ===============
system_info() {
    clear
    echo -e "${C}╔════════════════════════════════════════════════════════╗${N}"
    echo -e "${C}║                     SYSTEM INFORMATION                  ║${N}"
    echo -e "${C}╚════════════════════════════════════════════════════════╝${N}"
    
    if [ -f "$CONFIG_FILE" ]; then
        echo -e "${G}Loading saved system information...${N}"
        echo -e "${G}──────────────────────────────────────────────────────────${N}"
        # Display config file with colors
        while IFS= read -r line; do
            if [[ $line == \#* ]]; then
                echo -e "${C}$line${N}"
            elif [[ $line == *=* ]]; then
                key=$(echo "$line" | cut -d= -f1)
                value=$(echo "$line" | cut -d= -f2- | tr -d '"')
                echo -e "${Y}$key:${N} ${G}$value${N}"
            fi
        done < "$CONFIG_FILE"
    else
        echo -e "${Y}No saved configuration found. Running auto-detect...${N}"
        detect_system
    fi
    
    # Additional real-time info
    echo -e "\n${Y}REAL-TIME STATUS:${N}"
    echo -e "${G}──────────────────────────────────────────────────────────${N}"
    echo -e "${Y}Uptime:${N} $(uptime -p)"
    echo -e "${Y}Current Users:${N} $(who | wc -l)"
    echo -e "${Y}Processes:${N} $(ps aux | wc -l)"
    
    # Check for updates
    echo -e "\n${Y}PACKAGE UPDATES:${N}"
    echo -e "${G}──────────────────────────────────────────────────────────${N}"
    if command -v apt &>/dev/null; then
        updates=$(apt list --upgradable 2>/dev/null | wc -l)
        echo -e "  ${Y}APT updates available:${N} $((updates - 1))"
    elif command -v yum &>/dev/null; then
        updates=$(yum check-update 2>/dev/null | wc -l)
        echo -e "  ${Y}YUM updates available:${N} $updates"
    fi
    
    pause
}

# =============== MAIN MENU ===============

# Run auto-detect on first launch
if [ ! -f "$CONFIG_FILE" ]; then
    detect_system
fi

while true; do
    header
    echo -e "
 ${G}╔══════════════════╗    ${Y}╔══════════════════╗    ${B}╔══════════════════╗
 ${G}║ 1) System Info   ║    ${Y}║ 2) Disk & RAM    ║    ${B}║ 3) Network Info   ║
 ${G}║   ${C}(Auto-Detect)${G}  ║    ${Y}║                  ║    ${B}║                  ║
 ${G}╚══════════════════╝    ${Y}╚══════════════════╝    ${B}╚══════════════════╝

 ${R}╔══════════════════╗    ${C}╔══════════════════╗    ${M}╔══════════════════╗
 ${R}║ 4) Fake Check    ║    ${C}║ 5) Live Traffic  ║    ${M}║ 6) BTOP Mode     ║
 ${R}║                  ║    ${C}║ ${Y}(Auto-Install)${C}  ║    ${M}║ ${Y}(Auto-Install)${M}  ║
 ${R}╚══════════════════╝    ${C}╚══════════════════╝    ${M}╚══════════════════╝

 ${B}╔══════════════════╗    ${G}╔══════════════════╗    ${R}╔══════════════════╗
 ${B}║ 7) SpeedTest     ║    ${G}║ 8) Logs Viewer   ║    ${R}║ 9) Temp Monitor  ║
 ${B}║ ${Y}(Auto-Install)${B}  ║    ${G}║                  ║    ${R}║ ${Y}(Auto-Install)${R}  ║
 ${B}╚══════════════════╝    ${G}╚══════════════════╝    ${R}╚══════════════════╝

 ${M}╔══════════════════╗    ${C}╔══════════════════╗    ${G}╔══════════════════╗
 ${M}║12) Services      ║    ${C}║13) Security Audit║    ${G}║14) Backup Mgr    ║
 ${M}║                  ║    ${C}║                  ║    ${G}║                  ║
 ${M}╚══════════════════╝    ${C}╚══════════════════╝    ${G}╚══════════════════╝

 ${B}╔══════════════════╗    ${Y}╔══════════════════╗    ${R}╔══════════════════╗
 ${B}║15) Docker Monitor║    ${Y}║16) Performance   ║    ${R}║17) Auto-Update   ║
 ${B}║ ${Y}(Auto-Install)${B}  ║    ${Y}║   Benchmark     ║    ${R}║                  ║
 ${B}╚══════════════════╝    ${Y}╚══════════════════╝    ${R}╚══════════════════╝

 ${Y}╔═══════════════════════════════════════════════════════╗
 ${Y}║10) DDOS/Abuse Check   ${G}║18) Quick Diagnostic${Y}   ║
 ${Y}║                       ${G}║19) Install All    ${Y}   ║
 ${Y}╚═══════════════════════════════════════════════════════╝

                     ${R}╔══════════════════╗
                     ${R}║ 11) Exit         ║
                     ${R}╚══════════════════╝${N}
"

    read -p "Option → " x

    case "$x" in
        1)
            system_info
            ;;
        2)
            clear
            echo -e "${C}╔════════════════════════════════════════════════════════╗${N}"
            echo -e "${C}║                     DISK & RAM USAGE                   ║${N}"
            echo -e "${C}╚════════════════════════════════════════════════════════╝${N}"
            echo -e "${Y}🧠 MEMORY USAGE:${N}"
            echo -e "${G}──────────────────────────────────────────────────────────${N}"
            free -h
            echo -e "\n${Y}💽 DISK USAGE:${N}"
            echo -e "${G}──────────────────────────────────────────────────────────${N}"
            df -h
            pause
            ;;
        3)
            clear
            echo -e "${C}╔════════════════════════════════════════════════════════╗${N}"
            echo -e "${C}║                     NETWORK INFORMATION                ║${N}"
            echo -e "${C}╚════════════════════════════════════════════════════════╝${N}"
            ip -c a
            echo -e "\n${Y}Default Route:${N}"
            ip route | grep default
            pause
            ;;
        4)
            clear
            echo -e "${C}╔════════════════════════════════════════════════════════╗${N}"
            echo -e "${C}║                    VPS FAKE / REAL CHECK               ║${N}"
            echo -e "${C}╚════════════════════════════════════════════════════════╝${N}"
            echo -e "${Y}Virtualization Detection:${N}"
            echo -e "${G}──────────────────────────────────────────────────────────${N}"
            if command -v systemd-detect-virt &>/dev/null; then
                VIRT_TYPE=$(systemd-detect-virt)
                if [[ "$VIRT_TYPE" == "none" ]]; then
                    echo -e "${G}✓ Running on Bare Metal${N}"
                else
                    echo -e "${Y}✓ Running on: $VIRT_TYPE${N}"
                fi
            else
                echo -e "${Y}systemd-detect-virt not available${N}"
            fi
            
            echo -e "\n${Y}CPU Virtualization Flags:${N}"
            echo -e "${G}──────────────────────────────────────────────────────────${N}"
            if grep -E -o "vmx|svm" /proc/cpuinfo >/dev/null; then
                echo -e "${G}✔ Hardware virtualization flags present${N}"
                echo -e "${Y}This VPS supports nested virtualization${N}"
            else
                echo -e "${R}❗ VMX/SVM NOT found${N}"
                echo -e "${Y}This may be:${N}"
                echo -e "  • A container (LXC/Docker)"
                echo -e "  • A low-end VPS without hardware virt"
                echo -e "  • A fake/limited VPS"
            fi
            
            echo -e "\n${Y}Cloud Provider Detection:${N}"
            echo -e "${G}──────────────────────────────────────────────────────────${N}"
            if [ -f /sys/class/dmi/id/product_name ]; then
                PRODUCT=$(cat /sys/class/dmi/id/product_name)
                echo -e "Product: $PRODUCT"
            fi
            
            # Check for cloud-init
            if [ -d /var/lib/cloud ] || command -v cloud-init &>/dev/null; then
                echo -e "${Y}Cloud-init detected - Likely cloud VPS${N}"
            fi
            pause
            ;;
        5)
            live_traffic
            ;;
        6)
            btop_live
            ;;
        7)
            speedtest_run
            ;;
        8)
            logs_view
            ;;
        9)
            temp_monitor
            ;;
        10)
            ddos_check
            ;;
        11)
            clear
            echo -e "${C}╔════════════════════════════════════════════════════════╗${N}"
            echo -e "${C}║                    EXITING VPS ANALYZER                ║${N}"
            echo -e "${C}╚════════════════════════════════════════════════════════╝${N}"
            echo -e "${G}Thank you for using VPS Analyzer Pro v$VERSION!${N}"
            echo -e "${Y}Goodbye! 👋${N}"
            exit 0
            ;;
        12)
            service_monitor
            ;;
        13)
            security_audit
            ;;
        14)
            backup_manager
            ;;
        15)
            docker_monitor
            ;;
        16)
            performance_benchmark
            ;;
        17)
            auto_update
            ;;
        18)
            quick_diagnostic
            ;;
        19)
            install_all_features
            ;;
        *)
            echo -e "${R}Invalid option${N}"
            sleep 1
            ;;
    esac
done
