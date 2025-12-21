#!/bin/bash

# Colors
G="\e[32m"; R="\e[31m"; Y="\e[33m"; C="\e[36m"; W="\e[97m"; B="\e[34m"; M="\e[35m"; N="\e[0m"

# Function to print section headers
section() {
    echo -e "\n${B}════════════ $1 ════════════${N}"
}

# Function to print status messages
status() {
    echo -e "${C}[*]${N} $1"
}

success() {
    echo -e "${G}[✓]${N} $1"
}

error() {
    echo -e "${R}[✗]${N} $1"
}

warning() {
    echo -e "${Y}[!]${N} $1"
}

# Root check
[ "$EUID" -ne 0 ] && echo -e "${R}Run as root${N}" && exit 1

# All supported distributions with their init systems
declare -A DISTRO_IMAGES=(
    # Ubuntu/Debian family (use systemd image or custom)
    ["ubuntu:latest"]="Ubuntu Latest (no systemd)"
    ["ubuntu:22.04"]="Ubuntu 22.04 Jammy (no systemd)"
    ["ubuntu:20.04"]="Ubuntu 20.04 Focal (no systemd)"
    ["ubuntu:18.04"]="Ubuntu 18.04 Bionic (no systemd)"
    ["debian:latest"]="Debian Latest (no systemd)"
    ["debian:11"]="Debian 11 Bullseye (no systemd)"
    ["debian:10"]="Debian 10 Buster (no systemd)"
    
    # Systemd-enabled images
    ["ubuntu:jammy"]="Ubuntu 22.04 with systemd"
    ["debian:bullseye"]="Debian 11 with systemd"
    ["centos:7"]="CentOS 7 with systemd"
    ["rockylinux:8"]="Rocky Linux 8 with systemd"
    ["fedora:latest"]="Fedora Latest with systemd"
    ["archlinux:latest"]="Arch Linux with systemd"
)

# Systemd-enabled images (for auto-detection)
SYSTEMD_IMAGES=(
    "ubuntu:jammy"
    "debian:bullseye" 
    "centos:7"
    "rockylinux:8"
    "rockylinux:9"
    "almalinux:8"
    "almalinux:9"
    "fedora:latest"
    "fedora:38"
    "fedora:37"
    "archlinux:latest"
    "opensuse/leap:latest"
    "opensuse/tumbleweed:latest"
    "oraclelinux:8"
    "oraclelinux:9"
    "amazonlinux:2023"
    "amazonlinux:2"
)

# Default configuration
DEFAULT_IMAGE="ubuntu:jammy"
DEFAULT_PREFIX="sys_container"
DEFAULT_RAM="2g"
DEFAULT_CPU="1"
DEFAULT_SSD="20g"
DEFAULT_IPV4="auto"
DEFAULT_IPV6="auto"

# Check if image has systemd
has_systemd() {
    local image=$1
    for sysd_img in "${SYSTEMD_IMAGES[@]}"; do
        if [[ "$image" == "$sysd_img" ]]; then
            return 0
        fi
    done
    return 1
}

# Get init command for image
get_init_command() {
    local image=$1
    if has_systemd "$image"; then
        echo "/sbin/init"
    else
        echo "/bin/bash"
    fi
}

# Get package manager for image
get_package_manager() {
    local image=$1
    
    if [[ "$image" == *"ubuntu"* ]] || [[ "$image" == *"debian"* ]]; then
        echo "apt"
    elif [[ "$image" == *"centos"* ]] || [[ "$image" == *"rockylinux"* ]] || 
         [[ "$image" == *"almalinux"* ]] || [[ "$image" == *"oraclelinux"* ]] || 
         [[ "$image" == *"amazonlinux"* ]]; then
        echo "yum"
    elif [[ "$image" == *"fedora"* ]]; then
        echo "dnf"
    elif [[ "$image" == *"arch"* ]]; then
        echo "pacman"
    elif [[ "$image" == *"alpine"* ]]; then
        echo "apk"
    elif [[ "$image" == *"opensuse"* ]]; then
        echo "zypper"
    else
        echo "apt"
    fi
}

# Generate unique container name
generate_container_name() {
    local base_name="$1"
    local counter=1
    local new_name="$base_name"
    
    while docker ps -a --format '{{.Names}}' | grep -q "^${new_name}$"; do
        new_name="${base_name}_${counter}"
        ((counter++))
        if [ $counter -gt 20 ]; then
            new_name="${base_name}_$(date +%s)"
            break
        fi
    done
    
    echo "$new_name"
}

# Get resource allocation from user
get_resource_allocation() {
    echo -e "\n${B}════════════ RESOURCE ALLOCATION ════════════${N}"
    echo -e "${C}Set resource limits for container (Enter for default)${N}"
    
    # Memory/RAM
    read -p "RAM Memory (e.g., 2g, 512m) [$DEFAULT_RAM]: " ram
    RAM="${ram:-$DEFAULT_RAM}"
    
    # Validate RAM format
    if ! [[ "$RAM" =~ ^[0-9]+[mg]$ ]]; then
        warning "Invalid RAM format. Using default: $DEFAULT_RAM"
        RAM="$DEFAULT_RAM"
    fi
    
    # CPU
    read -p "CPU Cores (e.g., 2, 1.5) [$DEFAULT_CPU]: " cpu
    CPU="${cpu:-$DEFAULT_CPU}"
    
    # Validate CPU
    if ! [[ "$CPU" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        warning "Invalid CPU format. Using default: $DEFAULT_CPU"
        CPU="$DEFAULT_CPU"
    fi
    
    # Storage/SSD
    read -p "Storage Size (e.g., 20g, 100g) [$DEFAULT_SSD]: " ssd
    SSD="${ssd:-$DEFAULT_SSD}"
    
    if ! [[ "$SSD" =~ ^[0-9]+[mg]$ ]]; then
        warning "Invalid storage format. Using default: $DEFAULT_SSD"
        SSD="$DEFAULT_SSD"
    fi
    
    # Port mapping
    echo -e "\n${Y}Port Mapping (leave empty for none):${N}"
    echo -e "${C}Format: HOST_PORT:CONTAINER_PORT or RANGE_START-RANGE_END${N}"
    echo -e "${C}Examples: 80:80, 8080:80, 3000-4000:3000-4000${N}"
    read -p "Port mapping: " port_map
    
    # Network configuration
    echo -e "\n${Y}Network Configuration:${N}"
    echo -e "${G}1)${N} Auto (default)"
    echo -e "${G}2)${N} Bridge network"
    echo -e "${G}3)${N} Host network"
    echo -e "${G}4)${N} None (isolated)"
    read -p "Network mode [1-4]: " net_choice
    
    case $net_choice in
        2) NETWORK="bridge" ;;
        3) NETWORK="host" ;;
        4) NETWORK="none" ;;
        *) NETWORK="auto" ;;
    esac
    
    # IP configuration
    if [[ "$NETWORK" == "bridge" ]] || [[ "$NETWORK" == "auto" ]]; then
        echo -e "\n${Y}IP Configuration:${N}"
        read -p "IPv4 Address [auto]: " ipv4
        IPV4="${ipv4:-auto}"
        
        read -p "IPv6 Address [auto]: " ipv6
        IPV6="${ipv6:-auto}"
    fi
    
    echo -e "\n${G}Resource Summary:${N}"
    echo -e "  RAM: $RAM"
    echo -e "  CPU: $CPU cores"
    echo -e "  Storage: $SSD"
    echo -e "  Network: $NETWORK"
    if [[ "$NETWORK" != "none" ]]; then
        echo -e "  IPv4: $IPV4"
        echo -e "  IPv6: $IPV6"
    fi
    if [ -n "$port_map" ]; then
        echo -e "  Ports: $port_map"
    fi
}

# Display available images
display_images() {
    section "AVAILABLE IMAGES"
    
    echo -e "${G}Systemd-enabled Images (Recommended):${N}"
    echo "------------------------------------------------"
    for i in "${!SYSTEMD_IMAGES[@]}"; do
        img="${SYSTEMD_IMAGES[$i]}"
        printf "${G}%2d)${N} %-30s\n" "$((i+1))" "$img"
    done
    echo "------------------------------------------------"
    echo -e "${Y}Other Images (no systemd):${N}"
    echo "  ubuntu:latest, ubuntu:22.04, ubuntu:20.04, ubuntu:18.04"
    echo "  debian:latest, debian:11, debian:10"
    echo "------------------------------------------------"
    
    echo -e "\n${C}Select an option:${N}"
    echo -e "${G}1)${N} Use systemd-enabled image"
    echo -e "${Y}2)${N} Use other image"
    echo -e "${M}3)${N} Enter custom image"
    read -p "Choice [1-3]: " img_choice
    
    case $img_choice in
        1)
            read -p "Select image [1-${#SYSTEMD_IMAGES[@]}]: " select_num
            if [[ "$select_num" =~ ^[0-9]+$ ]] && [ "$select_num" -ge 1 ] && [ "$select_num" -le "${#SYSTEMD_IMAGES[@]}" ]; then
                IMAGE_NAME="${SYSTEMD_IMAGES[$((select_num-1))]}"
                success "Selected: $IMAGE_NAME"
                return 0
            else
                error "Invalid selection"
                return 1
            fi
            ;;
        2)
            echo -e "\n${Y}Available images:${N}"
            echo "  ubuntu:latest, ubuntu:22.04, ubuntu:20.04, ubuntu:18.04"
            echo "  debian:latest, debian:11, debian:10"
            read -p "Enter image name: " custom_img
            IMAGE_NAME="$custom_img"
            warning "Note: $IMAGE_NAME may not have systemd"
            return 0
            ;;
        3)
            read -p "Enter custom image (e.g., nginx:alpine): " custom_img
            IMAGE_NAME="$custom_img"
            warning "Using custom image: $IMAGE_NAME"
            return 0
            ;;
        *)
            error "Invalid choice"
            return 1
            ;;
    esac
}

# Check if image exists locally, pull if not
ensure_image_exists() {
    if ! docker image inspect "$IMAGE_NAME" &>/dev/null; then
        warning "Image $IMAGE_NAME not found locally"
        echo -e "${Y}Options:${N}"
        echo -e "${G}1)${N} Pull image now"
        echo -e "${Y}2)${N} Select different image"
        echo -e "${R}3)${N} Exit"
        
        read -p "Choice [1-3]: " pull_choice
        
        case $pull_choice in
            1)
                status "Pulling $IMAGE_NAME..."
                docker pull "$IMAGE_NAME"
                if [ $? -eq 0 ]; then
                    success "Image pulled successfully"
                    return 0
                else
                    error "Failed to pull image"
                    return 1
                fi
                ;;
            2)
                display_images
                ensure_image_exists
                ;;
            3)
                exit 0
                ;;
            *)
                error "Invalid choice"
                return 1
                ;;
        esac
    else
        success "Image found locally: $IMAGE_NAME"
        return 0
    fi
}

# Create container with specified resources
create_container_with_resources() {
    local name="$1"
    local image="$2"
    local ram="$3"
    local cpu="$4"
    local ssd="$5"
    local network="$6"
    local ipv4="$7"
    local ipv6="$8"
    local ports="$9"
    
    status "Creating container '$name' with resources..."
    
    # Build base command
    CMD="docker run -dit"
    
    # Container name and hostname
    CMD="$CMD --name '$name'"
    CMD="$CMD --hostname '$name'"
    
    # Resource limits
    CMD="$CMD --memory='$ram'"
    CMD="$CMD --cpus='$cpu'"
    
    # Storage limit (using tmpfs for root)
    CMD="$CMD --tmpfs /tmp:size=$ssd"
    
    # Network configuration
    case "$network" in
        "host")
            CMD="$CMD --network=host"
            ;;
        "none")
            CMD="$CMD --network=none"
            ;;
        "bridge")
            CMD="$CMD --network=bridge"
            if [[ "$ipv4" != "auto" ]]; then
                CMD="$CMD --ip '$ipv4'"
            fi
            if [[ "$ipv6" != "auto" ]]; then
                CMD="$CMD --ip6 '$ipv6'"
            fi
            ;;
        *)
            CMD="$CMD --network=bridge"
            ;;
    esac
    
    # Port mapping
    if [ -n "$ports" ]; then
        IFS=',' read -ra PORT_ARRAY <<< "$ports"
        for port in "${PORT_ARRAY[@]}"; do
            CMD="$CMD -p '$port'"
        done
    fi
    
    # For systemd containers
    if has_systemd "$image"; then
        CMD="$CMD --privileged"
        CMD="$CMD --cap-add=SYS_ADMIN"
        CMD="$CMD --cap-add=NET_ADMIN"
        CMD="$CMD --tmpfs /run"
        CMD="$CMD --tmpfs /run/lock"
        CMD="$CMD -v /sys/fs/cgroup:/sys/fs/cgroup:ro"
        CMD="$CMD -e container=docker"
        
        INIT_CMD="/sbin/init"
    else
        # For non-systemd containers
        CMD="$CMD -it"
        INIT_CMD="/bin/bash"
    fi
    
    # Add volume for persistent data
    CMD="$CMD -v '${name}-data:/data'"
    
    # Add image and init command
    CMD="$CMD '$image' '$INIT_CMD'"
    
    # Show command
    echo -e "${Y}Executing command:${N}"
    echo "$CMD" | sed 's/--/\n  --/g'
    echo
    
    # Execute
    eval "$CMD"
    
    if [ $? -eq 0 ]; then
        success "Container created successfully!"
        
        # For non-systemd containers, start bash session
        if ! has_systemd "$image"; then
            echo -e "${Y}Starting interactive session...${N}"
            echo -e "${C}Type 'exit' to return to menu${N}"
            docker attach "$name"
        fi
        
        return 0
    else
        error "Failed to create container"
        return 1
    fi
}

# Install systemd in Ubuntu/Debian if needed
install_systemd_in_container() {
    local container="$1"
    local image="$2"
    
    if [[ "$image" == *"ubuntu"* ]] || [[ "$image" == *"debian"* ]]; then
        if ! has_systemd "$image"; then
            echo -e "${Y}Installing systemd in container...${N}"
            docker exec "$container" apt update
            docker exec "$container" apt install -y systemd systemd-sysv dbus
            docker exec "$container" apt install -y curl wget nano vim htop
        fi
    fi
}

# Main menu
main_menu() {
    while true; do
        clear
        echo -e "${B}╔════════════════════════════════════════════════╗${N}"
        echo -e "${B}║${W}        DOCKER CONTAINER MANAGER v2.0          ${B}║${N}"
        echo -e "${B}╠════════════════════════════════════════════════╣${N}"
        echo -e "${B}║${G} 1️⃣   Create New Container with Resources      ${B}║${N}"
        echo -e "${B}║${Y} 2️⃣   Manage Existing Containers              ${B}║${N}"
        echo -e "${B}║${C} 3️⃣   Enter Container Menu                    ${B}║${N}"
        echo -e "${B}║${M} 4️⃣   View All Containers                     ${B}║${N}"
        echo -e "${B}║${R} 5️⃣   Exit                                    ${B}║${N}"
        echo -e "${B}╚════════════════════════════════════════════════╝${N}"
        echo
        
        read -p "Select [1-5]: " choice
        
        case $choice in
            1)
                create_container_flow
                ;;
            2)
                manage_containers
                ;;
            3)
                enter_container_menu
                ;;
            4)
                docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
                echo
                read -p "Press Enter to continue..."
                ;;
            5)
                echo -e "${G}Goodbye!${N}"
                exit 0
                ;;
            *)
                echo -e "${R}Invalid option${N}"
                sleep 1
                ;;
        esac
    done
}

# Create container flow
create_container_flow() {
    section "CREATE NEW CONTAINER"
    
    # Get container name
    CONTAINER_NAME=$(generate_container_name "$DEFAULT_PREFIX")
    read -p "Container name [$CONTAINER_NAME]: " custom_name
    if [ -n "$custom_name" ]; then
        CONTAINER_NAME="$custom_name"
        if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
            CONTAINER_NAME=$(generate_container_name "$CONTAINER_NAME")
            warning "Name exists, using: $CONTAINER_NAME"
        fi
    fi
    
    # Select image
    display_images || return 1
    ensure_image_exists || return 1
    
    # Get resource allocation
    get_resource_allocation
    
    # Confirm
    echo -e "\n${B}════════════ CONFIRMATION ════════════${N}"
    echo -e "${C}Create container with these settings?${N}"
    echo -e "  Name: $CONTAINER_NAME"
    echo -e "  Image: $IMAGE_NAME"
    echo -e "  RAM: $RAM"
    echo -e "  CPU: $CPU"
    echo -e "  Storage: $SSD"
    echo -e "  Network: $NETWORK"
    
    read -p "Proceed? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        warning "Cancelled"
        return 1
    fi
    
    # Create container
    create_container_with_resources \
        "$CONTAINER_NAME" \
        "$IMAGE_NAME" \
        "$RAM" \
        "$CPU" \
        "$SSD" \
        "$NETWORK" \
        "$IPV4" \
        "$IPV6" \
        "$port_map"
    
    if [ $? -eq 0 ]; then
        # Install tools if needed
        install_systemd_in_container "$CONTAINER_NAME" "$IMAGE_NAME"
        
        # Show container info
        show_container_info "$CONTAINER_NAME"
        
        # Ask to enter container
        if has_systemd "$IMAGE_NAME"; then
            read -p "Enter container menu now? [y/N]: " enter_now
            if [[ "$enter_now" =~ ^[Yy]$ ]]; then
                enter_container "$CONTAINER_NAME"
            fi
        fi
    fi
    
    echo
    read -p "Press Enter to continue..."
}

# Manage existing containers
manage_containers() {
    section "MANAGE CONTAINERS"
    
    containers=$(docker ps -a --format "{{.Names}}")
    if [ -z "$containers" ]; then
        echo -e "${Y}No containers found${N}"
        read -p "Press Enter to continue..."
        return
    fi
    
    echo -e "${C}Existing containers:${N}"
    select container in $containers "Back"; do
        if [ "$container" = "Back" ]; then
            return
        elif [ -n "$container" ]; then
            container_menu "$container"
            break
        fi
    done
}

# Container management menu
container_menu() {
    local container=$1
    
    while true; do
        clear
        echo -e "${B}════════════ MANAGING: $container ════════════${N}"
        
        # Get container status
        status=$(docker inspect -f '{{.State.Status}}' "$container" 2>/dev/null)
        if [ -z "$status" ]; then
            error "Container not found"
            return 1
        fi
        
        echo -e "${G}Status:${N} $status"
        echo -e "${G}Image:${N} $(docker inspect -f '{{.Config.Image}}' "$container")"
        echo -e "${G}IP:${N} $(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$container" 2>/dev/null || echo 'N/A')"
        
        echo -e "\n${C}Actions:${N}"
        echo -e "${G}1)${N} Start"
        echo -e "${Y}2)${N} Stop"
        echo -e "${C}3)${N} Restart"
        echo -e "${M}4)${N} Remove"
        echo -e "${W}5)${N} View Logs"
        echo -e "${G}6)${N} Execute Command"
        echo -e "${Y}7)${N} Enter Shell"
        echo -e "${R}8)${N} Back"
        
        read -p "Select [1-8]: " action
        
        case $action in
            1)
                docker start "$container"
                success "Container started"
                sleep 1
                ;;
            2)
                docker stop "$container"
                success "Container stopped"
                sleep 1
                ;;
            3)
                docker restart "$container"
                success "Container restarted"
                sleep 1
                ;;
            4)
                read -p "Remove container $container? [y/N]: " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    docker rm -f "$container"
                    success "Container removed"
                    return 0
                fi
                ;;
            5)
                docker logs --tail 50 "$container"
                echo
                read -p "Press Enter to continue..."
                ;;
            6)
                read -p "Command to execute: " cmd
                if [ -n "$cmd" ]; then
                    docker exec "$container" bash -c "$cmd"
                fi
                echo
                read -p "Press Enter to continue..."
                ;;
            7)
                echo -e "${Y}Entering container shell...${N}"
                echo -e "${C}Type 'exit' to return${N}"
                docker exec -it "$container" bash || docker exec -it "$container" sh
                ;;
            8)
                return
                ;;
            *)
                error "Invalid option"
                sleep 1
                ;;
        esac
    done
}

# Enter container management menu
enter_container_menu() {
    section "ENTER CONTAINER MENU"
    
    containers=$(docker ps --format "{{.Names}}")
    if [ -z "$containers" ]; then
        echo -e "${Y}No running containers found${N}"
        read -p "Press Enter to continue..."
        return
    fi
    
    echo -e "${C}Running containers:${N}"
    select container in $containers "Back"; do
        if [ "$container" = "Back" ]; then
            return
        elif [ -n "$container" ]; then
            enter_container "$container"
            break
        fi
    done
}

# Enter container with management menu
enter_container() {
    local container=$1
    
    # Check if container has systemd menu
    if docker exec "$container" test -f /root/container-system.sh 2>/dev/null; then
        docker exec -it "$container" bash /root/container-system.sh
    else
        # Create basic menu if not exists
        warning "No management menu found. Creating basic menu..."
        create_basic_menu "$container"
        docker exec -it "$container" bash /root/container-system.sh
    fi
}

# Create basic management menu
create_basic_menu() {
    local container=$1
    local image=$(docker inspect -f '{{.Config.Image}}' "$container")
    
    docker exec "$container" bash -c 'cat > /root/container-system.sh' <<'EOF'
#!/bin/bash

# Colors
G="\e[32m"; R="\e[31m"; Y="\e[33m"; C="\e[36m"; W="\e[97m"; B="\e[34m"; N="\e[0m"

while true; do
clear
echo -e "${B}╔════════════════════════════════════════════════╗${N}"
echo -e "${B}║${W}          CONTAINER MANAGEMENT MENU            ${B}║${N}"
echo -e "${B}╠════════════════════════════════════════════════╣${N}"
echo -e "${B}║${G} 1) System Information                         ${B}║${N}"
echo -e "${B}║${Y} 2) Install Packages                           ${B}║${N}"
echo -e "${B}║${C} 3) Network Configuration                      ${B}║${N}"
echo -e "${B}║${W} 4) Process Management                         ${B}║${N}"
echo -e "${B}║${M} 5) File Browser                               ${B}║${N}"
echo -e "${B}║${G} 6) Run Custom Command                         ${B}║${N}"
echo -e "${B}║${R} 7) Exit to Host                               ${B}║${N}"
echo -e "${B}╚════════════════════════════════════════════════╝${N}"
echo -e "${C}Hostname: $(hostname)${N}"
echo

read -p "Select [1-7]: " choice

case $choice in
1)
  echo -e "${B}════════════ SYSTEM INFO ════════════${N}"
  echo -e "${G}OS:${N}"
  cat /etc/os-release 2>/dev/null | grep -E "PRETTY_NAME|NAME|VERSION"
  echo -e "\n${G}Uptime:${N}"
  uptime
  echo -e "\n${G}Resources:${N}"
  echo -e "CPU: $(nproc) cores"
  free -h | awk '/^Mem:/ {print "RAM: " $3 "/" $2}'
  df -h / | awk 'NR==2 {print "Disk: " $3 "/" $2 " used"}'
  ;;
2)
  echo -e "${B}════════════ INSTALL PACKAGES ════════════${N}"
  if command -v apt &>/dev/null; then
    read -p "Package name: " pkg
    apt update && apt install -y "$pkg"
  elif command -v yum &>/dev/null; then
    read -p "Package name: " pkg
    yum install -y "$pkg"
  elif command -v apk &>/dev/null; then
    read -p "Package name: " pkg
    apk add "$pkg"
  else
    echo "Unknown package manager"
  fi
  ;;
3)
  echo -e "${B}════════════ NETWORK ════════════${N}"
  echo -e "${G}IP Address:${N} $(hostname -I 2>/dev/null || echo 'N/A')"
  echo -e "\n${G}Connections:${N}"
  ss -tulpn 2>/dev/null | head -20
  ;;
4)
  echo -e "${B}════════════ PROCESSES ════════════${N}"
  ps aux --sort=-%cpu | head -20
  ;;
5)
  echo -e "${B}════════════ FILE BROWSER ════════════${N}"
  read -p "Directory [/]: " dir
  ls -la "${dir:-/}" | head -30
  ;;
6)
  echo -e "${B}════════════ CUSTOM COMMAND ════════════${N}"
  read -p "Command: " cmd
  if [ -n "$cmd" ]; then
    echo -e "${Y}Output:${N}"
    eval "$cmd"
  fi
  ;;
7)
  echo -e "${G}Exiting...${N}"
  exit 0
  ;;
*)
  echo -e "${R}Invalid option${N}"
  ;;
esac

echo
read -p "Press Enter to continue..."
done
EOF

    docker exec "$container" chmod +x /root/container-system.sh
    success "Basic menu created"
}

# Show container info
show_container_info() {
    local container=$1
    
    section "CONTAINER INFO"
    
    echo -e "${G}Container:${N} $container"
    echo -e "${G}Status:${N} $(docker inspect -f '{{.State.Status}}' "$container")"
    echo -e "${G}Image:${N} $(docker inspect -f '{{.Config.Image}}' "$container")"
    echo -e "${G}IP Address:${N} $(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$container" 2>/dev/null || echo 'N/A')"
    echo -e "${G}Created:${N} $(docker inspect -f '{{.Created}}' "$container" | cut -d'T' -f1)"
    echo -e "${G}Ports:${N} $(docker port "$container" 2>/dev/null | tr '\n' ',' | sed 's/,$//' || echo 'None')"
    
    # Resource usage
    echo -e "\n${G}Resource Usage:${N}"
    docker stats "$container" --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}"
}

# Cleanup on exit
cleanup() {
    echo -e "\n${Y}Exiting...${N}"
    exit 0
}
trap cleanup SIGINT SIGTERM

# Main execution
section "DOCKER CONTAINER MANAGER"
echo -e "${W}Complete Container Management with Resource Allocation${N}"

# Check Docker
if ! command -v docker &>/dev/null; then
    error "Docker not installed. Please install Docker first."
    exit 1
fi

# Start main menu
main_menu
