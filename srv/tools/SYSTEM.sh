#!/bin/bash

# =============== COLORS ===============
R="\e[31m"; G="\e[32m"; Y="\e[33m"; B="\e[34m"; C="\e[36m"; M="\e[35m"; W="\e[37m"; N="\e[0m"

# =============== HELPERS ===============
pause() {
    echo
    read -p "↩ Press Enter to return to menu..." _
}

header() {
    clear
    echo -e "${C}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║                 VPS ANALYZER PRO UI v2.0                 ║"
    echo "╚══════════════════════════════════════════════════════════╝${N}"
}

# =============== SPEEDTEST ===============
speedtest_run() {
    clear
    echo -e "${Y}🚀 INTERNET SPEEDTEST${N}"
    if ! command -v speedtest-cli &>/dev/null; then
        echo -e "${R}speedtest-cli missing → installing...${N}"
        sudo apt update -y && sudo apt install -y speedtest-cli
    fi
    speedtest-cli --simple
    pause
}

# =============== LOG VIEWER ===============
logs_view() {
    clear
    echo -e "${C}📜 System Logs (last 50 lines)${N}"
    journalctl -n 50 --no-pager | sed 's/^/   /'
    pause
}

# =============== TEMPERATURE MONITOR ===============
temp_monitor() {
    clear
    echo -e "${Y}🌡 TEMPERATURE MONITOR${N}"
    if ! command -v sensors &>/dev/null; then
        echo -e "${G}Installing lm-sensors...${N}"
        sudo apt update -y && sudo apt install -y lm-sensors
        sudo sensors-detect --auto
    fi
    echo -e "${C}Live temperatures (refresh 1s) — CTRL+C to exit${N}"
    sleep 1
    watch -n 1 sensors
}

# =============== DDOS / ABUSE CHECK ===============
ddos_check() {
    clear
    while true; do
        clear
        echo -e "${R}⚠ LIVE ATTACK / CONNECTION WATCH${N}"
        echo
        echo -e "${C}Top IPs by connection count:${N}"
        ss -tuna | awk 'NR>1{print $5}' | cut -d: -f1 | sort | uniq -c | sort -nr | head
        echo
        echo -e "${Y}CPU Load:${N} $(uptime | awk -F'load average:' '{print $2}')"
        echo -e "\n⏳ Refreshing every 2s...   CTRL+C to exit"
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
    printf "%0.s░" $(seq 1 $empty)
    printf "${R}]${N}"
}

# =============== BTOP-LIKE LIVE DASHBOARD ===============
btop_live() {
    while true; do
        clear
        echo -e "${C}══════════  VPS BTOP LIVE MONITOR  ══════════${N}"

        # CPU per core (requires mpstat from sysstat)
        if command -v mpstat >/dev/null 2>&1; then
            echo -e "${Y}CPU Per-Core Usage:${N}"
            mpstat -P ALL 1 1 | awk '/Average/ && $2 ~ /[0-9]/ {printf "Core %-2s : %3s%%\n",$2,100-$12}'
        else
            echo -e "${R}mpstat not installed.${N} Install: ${Y}sudo apt install sysstat -y${N}"
        fi

        # RAM
        mem_used=$(free -m | awk '/Mem/ {print $3}')
        mem_total=$(free -m | awk '/Mem/ {print $2}')
        echo -e "\n${Y}RAM:${N}"
        draw_bar "$mem_used" "$mem_total"
        echo -e "  (${mem_used}MB / ${mem_total}MB)"

        # DISK (/)
        disk_used=$(df / | awk 'NR==2 {print $3}')
        disk_total=$(df / | awk 'NR==2 {print $2}')
        echo -e "\n${Y}DISK (/):${N}"
        draw_bar "$disk_used" "$disk_total"
        echo -e "  (${disk_used}MB / ${disk_total}MB)"

        # TOP PROCESSES
        echo -e "\n${B}🔥 Top CPU Processes:${N}"
        ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%cpu | head -10

        # NETWORK SPEED
        rx1=$(cat /sys/class/net/*/statistics/rx_bytes 2>/dev/null | paste -sd+)
        tx1=$(cat /sys/class/net/*/statistics/tx_bytes 2>/dev/null | paste -sd+)
        sleep 1
        rx2=$(cat /sys/class/net/*/statistics/rx_bytes 2>/dev/null | paste -sd+)
        tx2=$(cat /sys/class/net/*/statistics/tx_bytes 2>/dev/null | paste -sd+)

        rx_kb=$(( (rx2 - rx1) / 1024 ))
        tx_kb=$(( (tx2 - tx1) / 1024 ))
        echo -e "\n${G}NET:${N} ⬇ ${rx_kb} KB/s   ⬆ ${tx_kb} KB/s"

        echo -e "\n${C}Press CTRL+C to exit BTOP mode...${N}"
    done
}

# =============== NEW FEATURES ===============

# 12) SERVICE MONITOR
service_monitor() {
    clear
    echo -e "${M}🔧 SERVICE STATUS MONITOR${N}"
    echo
    echo -e "${Y}1) List all services${N}"
    echo -e "${Y}2) Check specific service${N}"
    echo -e "${Y}3) Start/Stop service${N}"
    echo -e "${Y}4) Enable/Disable at boot${N}"
    echo
    read -p "Choose option [1-4]: " service_opt
    
    case $service_opt in
        1)
            systemctl list-units --type=service --no-pager | head -30
            ;;
        2)
            read -p "Enter service name (e.g., nginx, sshd): " svc_name
            systemctl status "$svc_name" --no-pager
            ;;
        3)
            read -p "Service name: " svc_name
            echo -e "${Y}1) Start${N}"
            echo -e "${Y}2) Stop${N}"
            echo -e "${Y}3) Restart${N}"
            read -p "Action [1-3]: " action
            case $action in
                1) sudo systemctl start "$svc_name" ;;
                2) sudo systemctl stop "$svc_name" ;;
                3) sudo systemctl restart "$svc_name" ;;
                *) echo "Invalid option" ;;
            esac
            systemctl status "$svc_name" --no-pager | head -10
            ;;
        4)
            read -p "Service name: " svc_name
            echo -e "${Y}1) Enable at boot${N}"
            echo -e "${Y}2) Disable at boot${N}"
            read -p "Action [1-2]: " action
            case $action in
                1) sudo systemctl enable "$svc_name" ;;
                2) sudo systemctl disable "$svc_name" ;;
                *) echo "Invalid option" ;;
            esac
            ;;
        *)
            echo "Invalid option"
            ;;
    esac
    pause
}

# 13) SECURITY AUDIT
security_audit() {
    clear
    echo -e "${R}🔐 SECURITY AUDIT${N}"
    echo
    echo -e "${Y}🛡️ SSH Security Check:${N}"
    grep -E "^PermitRootLogin" /etc/ssh/sshd_config 2>/dev/null || echo "PermitRootLogin not found"
    grep -E "^PasswordAuthentication" /etc/ssh/sshd_config 2>/dev/null || echo "PasswordAuthentication not found"
    
    echo -e "\n${Y}🔍 Failed Login Attempts:${N}"
    lastb | head -10
    
    echo -e "\n${Y}👥 Users with sudo:${N}"
    grep -Po '^sudo.+:\K.*$' /etc/group | tr ',' '\n'
    
    echo -e "\n${Y}🔐 Open Ports:${N}"
    ss -tuln | grep LISTEN
    
    pause
}

# 14) BACKUP MANAGER
backup_manager() {
    clear
    echo -e "${G}💾 BACKUP MANAGER${N}"
    echo
    echo -e "${Y}1) Quick backup (home directory)${N}"
    echo -e "${Y}2) Backup specific folder${N}"
    echo -e "${Y}3) Schedule automatic backup${N}"
    echo -e "${Y}4) List backup files${N}"
    echo
    read -p "Choose option [1-4]: " backup_opt
    
    case $backup_opt in
        1)
            backup_file="backup_home_$(date +%Y%m%d_%H%M%S).tar.gz"
            echo -e "${C}Creating backup of /home to ~/$backup_file${N}"
            tar -czf ~/"$backup_file" /home 2>/dev/null
            echo -e "${G}Backup created: ~/$backup_file${N}"
            du -h ~/"$backup_file" | awk '{print "Size:", $1}'
            ;;
        2)
            read -p "Enter folder path to backup: " folder_path
            if [ -d "$folder_path" ]; then
                folder_name=$(basename "$folder_path")
                backup_file="backup_${folder_name}_$(date +%Y%m%d_%H%M%S).tar.gz"
                tar -czf ~/"$backup_file" "$folder_path" 2>/dev/null
                echo -e "${G}Backup created: ~/$backup_file${N}"
            else
                echo -e "${R}Folder not found!${N}"
            fi
            ;;
        3)
            echo -e "${Y}Coming soon... Use cron for scheduling${N}"
            ;;
        4)
            echo -e "${C}Backup files in home directory:${N}"
            ls -lh ~/backup_* 2>/dev/null || echo "No backup files found"
            ;;
        *)
            echo "Invalid option"
            ;;
    esac
    pause
}

# 15) DOCKER MONITOR
docker_monitor() {
    clear
    echo -e "${B}🐳 DOCKER MONITOR${N}"
    
    if ! command -v docker &>/dev/null; then
        echo -e "${R}Docker is not installed${N}"
        echo -e "Install with: ${Y}sudo apt install docker.io -y${N}"
        pause
        return
    fi
    
    echo -e "${Y}1) List containers${N}"
    echo -e "${Y}2) List images${N}"
    echo -e "${Y}3) Container stats${N}"
    echo -e "${Y}4) Docker disk usage${N}"
    echo
    read -p "Choose option [1-4]: " docker_opt
    
    case $docker_opt in
        1)
            echo -e "${C}Running containers:${N}"
            docker ps
            echo -e "\n${C}All containers:${N}"
            docker ps -a
            ;;
        2)
            docker images
            ;;
        3)
            docker stats --no-stream
            ;;
        4)
            docker system df
            ;;
        *)
            echo "Invalid option"
            ;;
    esac
    pause
}

# 16) PERFORMANCE BENCHMARK
performance_benchmark() {
    clear
    echo -e "${Y}📊 PERFORMANCE BENCHMARK${N}"
    
    echo -e "${C}Running CPU benchmark (30 seconds)...${N}"
    echo -e "CPU BogoMips: $(grep -i bogomips /proc/cpuinfo | head -1 | awk -F: '{print $2}')"
    
    # Simple CPU test
    echo -e "\n${Y}CPU Test (calculating π):${N}"
    time echo "scale=5000; 4*a(1)" | bc -l 2>&1 | tail -3
    
    # Disk speed test
    echo -e "\n${Y}Disk Write Speed:${N}"
    dd if=/dev/zero of=/tmp/testfile bs=1M count=100 2>&1 | tail -1
    rm -f /tmp/testfile
    
    # Memory speed test
    echo -e "\n${Y}Memory Speed:${N}"
    if command -v sysbench &>/dev/null; then
        sysbench memory --memory-block-size=1M --memory-total-size=1G run 2>/dev/null | grep -E "transferred|seconds"
    else
        echo "Install sysbench for detailed memory test"
    fi
    
    pause
}

# =============== MAIN MENU (UPDATED UI) ===============
while true; do
    header
    echo -e "
 ${G}╔═══════════════╗    ${Y}╔═══════════════╗    ${B}╔═══════════════╗
 ${G}║ 1) System Info║    ${Y}║ 2) Disk+RAM   ║    ${B}║ 3) Network     ║
 ${G}╚═══════════════╝    ${Y}╚═══════════════╝    ${B}╚═══════════════╝

 ${R}╔═══════════════╗    ${C}╔════════════════╗    ${Y}╔═══════════════╗
 ${R}║ 4) Fake Check ║    ${C}║ 5) Live Traffic║    ${Y}║ 6) BTOP Mode  ║
 ${R}╚═══════════════╝    ${C}╚════════════════╝    ${Y}╚═══════════════╝

 ${B}╔═══════════════╗    ${G}╔════════════════╗    ${R}╔═══════════════╗
 ${B}║ 7) SpeedTest  ║    ${G}║ 8) Logs Viewer ║    ${R}║ 9) Temp Monitor║
 ${B}╚═══════════════╝    ${G}╚════════════════╝    ${R}╚═══════════════╝

 ${M}╔═══════════════╗    ${C}╔════════════════╗    ${G}╔═══════════════╗
 ${M}║12) Services   ║    ${C}║13) Security    ║    ${G}║14) Backup      ║
 ${M}╚═══════════════╝    ${C}╚════════════════╝    ${G}╚═══════════════╝

 ${B}╔═══════════════╗    ${Y}╔════════════════╗    ${R}╔═══════════════╗
 ${B}║15) Docker     ║    ${Y}║16) Performance ║    ${R}║17) Update Tool ║
 ${B}╚═══════════════╝    ${Y}╚════════════════╝    ${R}╚═══════════════╝

                    ${Y}╔═════════════════════╗
                    ${Y}║10) DDOS/Abuse Check ║
                    ${Y}╚═════════════════════╝

                     ${R}╔══════════════╗
                     ${R}║ 11) Exit     ║
                     ${R}╚══════════════╝${N}
"

    read -p "Option → " x

    case "$x" in
        1)
            clear
            echo -e "${G}📌 SYSTEM INFO${N}"
            hostnamectl
            pause
            ;;
        2)
            clear
            echo -e "${Y}🧠 RAM:${N}"
            free -h
            echo
            echo -e "${Y}💽 DISK:${N}"
            df -h
            pause
            ;;
        3)
            clear
            echo -e "${C}🌐 NETWORK INFO${N}"
            ip a
            pause
            ;;
        4)
            clear
            echo -e "${R}🕵 VPS FAKE / REAL CHECK${N}"
            echo -e "${Y}Virtualization:${N}"
            systemd-detect-virt
            echo
            echo -e "${Y}CPU VMX/SVM Flags:${N}"
            if grep -E -o "vmx|svm" /proc/cpuinfo >/dev/null; then
                echo -e "${G}✔ Hardware virtualization flags present${N}"
            else
                echo -e "${R}❗ VMX/SVM NOT found — may be weak/fake VPS${N}"
            fi
            pause
            ;;
        5)
            clear
            echo -e "${C}📡 LIVE TRAFFIC (iftop)${N}"
            if command -v iftop >/dev/null 2>&1; then
                echo -e "${Y}Ctrl+C to exit, then Enter to return to menu.${N}"
                sleep 1
                iftop -n -P
            else
                echo -e "${R}iftop not installed.${N}"
                echo -e "Install with: ${Y}sudo apt install iftop -y${N}"
            fi
            pause
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
            echo -e "${Y}Exiting VPS Analyzer Pro. Bye!${N}"
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
            clear
            echo -e "${C}🔄 UPDATING VPS ANALYZER PRO${N}"
            echo "This would update the tool from GitHub..."
            echo "Update feature placeholder"
            pause
            ;;
        *)
            echo "Invalid option"; sleep 1 ;;
    esac
done
