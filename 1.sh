#!/bin/bash
set -euo pipefail

# =============================
# Docker Container Manager
# =============================

# Function to display header
display_header() {
    clear
    cat << "EOF"
██████╗  ██████╗  ██████╗██╗  ██╗███████╗██████╗ 
██╔══██╗██╔═══██╗██╔════╝██║ ██╔╝██╔════╝██╔══██╗
██║  ██║██║   ██║██║     █████╔╝ █████╗  ██████╔╝
██║  ██║██║   ██║██║     ██╔═██╗ ██╔══╝  ██╔══██╗
██████╔╝╚██████╔╝╚██████╗██║  ██╗███████╗██║  ██║
╚═════╝  ╚═════╝  ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝
            Container Management System
EOF
    echo
}

# Function to display colored output with emojis
print_status() {
    local type=$1
    local message=$2
    
    case $type in
        "INFO") echo -e "\033[1;34m📋 [INFO]\033[0m $message" ;;
        "WARN") echo -e "\033[1;33m⚠️  [WARN]\033[0m $message" ;;
        "ERROR") echo -e "\033[1;31m❌ [ERROR]\033[0m $message" ;;
        "SUCCESS") echo -e "\033[1;32m✅ [SUCCESS]\033[0m $message" ;;
        "INPUT") echo -e "\033[1;36m🎯 [INPUT]\033[0m $message" ;;
        *) echo "[$type] $message" ;;
    esac
}

# Function to check dependencies
check_dependencies() {
    if ! command -v docker &> /dev/null; then
        print_status "ERROR" "🔧 Docker is not installed"
        print_status "INFO" "💡 To install Docker on Ubuntu/Debian:"
        echo "    curl -fsSL https://get.docker.com -o get-docker.sh"
        echo "    sudo sh get-docker.sh"
        echo "    sudo usermod -aG docker \$USER"
        exit 1
    fi
    
    # Check if user is in docker group
    if ! groups | grep -q docker; then
        print_status "WARN" "👤 Current user is not in docker group"
        print_status "INFO" "💡 Run: sudo usermod -aG docker \$USER"
        print_status "INFO" "💡 Then logout and login again"
    fi
}

# Function to get all container configurations
get_container_list() {
    find "$CONTAINER_DIR" -name "*.conf" -exec basename {} .conf \; 2>/dev/null | sort
}

# Function to load container configuration
load_container_config() {
    local container_name=$1
    local config_file="$CONTAINER_DIR/$container_name.conf"
    
    if [[ -f "$config_file" ]]; then
        # Clear previous variables
        unset CONTAINER_NAME IMAGE_NAME CONTAINER_TYPE MEMORY CPUS STORAGE 
        unset NETWORK_MODE IPV4_ADDRESS IPV6_ADDRESS PORTS VOLUMES ENV_VARS
        unset CREATED_STATUS
        
        source "$config_file"
        return 0
    else
        print_status "ERROR" "📂 Configuration for container '$container_name' not found"
        return 1
    fi
}

# Function to save container configuration
save_container_config() {
    local config_file="$CONTAINER_DIR/$CONTAINER_NAME.conf"
    
    cat > "$config_file" <<EOF
CONTAINER_NAME="$CONTAINER_NAME"
IMAGE_NAME="$IMAGE_NAME"
CONTAINER_TYPE="$CONTAINER_TYPE"
MEMORY="$MEMORY"
CPUS="$CPUS"
STORAGE="$STORAGE"
NETWORK_MODE="$NETWORK_MODE"
IPV4_ADDRESS="$IPV4_ADDRESS"
IPV6_ADDRESS="$IPV6_ADDRESS"
PORTS="$PORTS"
VOLUMES="$VOLUMES"
ENV_VARS="$ENV_VARS"
CREATED="$CREATED"
STATUS="$STATUS"
EOF
    
    print_status "SUCCESS" "💾 Configuration saved to $config_file"
}

# Function to validate input
validate_input() {
    local type=$1
    local value=$2
    
    case $type in
        "number")
            if ! [[ "$value" =~ ^[0-9]+$ ]]; then
                print_status "ERROR" "❌ Must be a number"
                return 1
            fi
            ;;
        "size")
            if ! [[ "$value" =~ ^[0-9]+[GgMm]$ ]]; then
                print_status "ERROR" "❌ Must be a size with unit (e.g., 100G, 512M)"
                return 1
            fi
            ;;
        "port")
            if ! [[ "$value" =~ ^[0-9]+$ ]] || [ "$value" -lt 1 ] || [ "$value" -gt 65535 ]; then
                print_status "ERROR" "❌ Must be a valid port number (1-65535)"
                return 1
            fi
            ;;
        "name")
            if ! [[ "$value" =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]+$ ]]; then
                print_status "ERROR" "❌ Container name can only contain letters, numbers, dots, hyphens, and underscores"
                return 1
            fi
            ;;
        "ipv4")
            if ! [[ "$value" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || [[ "$value" == "0.0.0.0" ]] || [[ "$value" == "auto" ]]; then
                if [[ "$value" != "auto" ]]; then
                    print_status "ERROR" "❌ Must be a valid IPv4 address or 'auto'"
                    return 1
                fi
            fi
            ;;
        "ipv6")
            if [[ -n "$value" ]] && [[ "$value" != "auto" ]]; then
                print_status "ERROR" "❌ Only 'auto' is currently supported for IPv6"
                return 1
            fi
            ;;
    esac
    return 0
}

# Function to create new container
create_new_container() {
    print_status "INFO" "🆕 Creating a new container"
    
    # Container name
    while true; do
        read -p "$(print_status "INPUT" "🏷️  Enter container name: ")" CONTAINER_NAME
        if validate_input "name" "$CONTAINER_NAME"; then
            # Check if container name already exists
            if [[ -f "$CONTAINER_DIR/$CONTAINER_NAME.conf" ]] || docker ps -a --format '{{.Names}}' | grep -q "^$CONTAINER_NAME$"; then
                print_status "ERROR" "⚠️  Container with name '$CONTAINER_NAME' already exists"
            else
                break
            fi
        fi
    done

    # Container type selection
    print_status "INFO" "📦 Select container type:"
    echo "  1) 🐧 Systemd Container (Full OS with systemd)"
    echo "  2) ⚡ Lightweight Container (Minimal OS)"
    echo "  3) 🛠️  Application Container (Single app)"
    echo "  4) 🎯 Custom Container"
    
    while true; do
        read -p "$(print_status "INPUT" "🎯 Enter your choice (1-4): ")" type_choice
        case $type_choice in
            1) 
                CONTAINER_TYPE="systemd"
                break
                ;;
            2)
                CONTAINER_TYPE="lightweight"
                break
                ;;
            3)
                CONTAINER_TYPE="application"
                break
                ;;
            4)
                CONTAINER_TYPE="custom"
                break
                ;;
            *)
                print_status "ERROR" "❌ Invalid selection"
                ;;
        esac
    done

    # Image selection based on type
    case $CONTAINER_TYPE in
        "systemd")
            print_status "INFO" "🐧 Select a systemd-enabled image:"
            echo "  1) Ubuntu 22.04 with systemd"
            echo "  2) Debian 11 with systemd"
            echo "  3) CentOS 7 with systemd"
            echo "  4) Fedora Latest with systemd"
            echo "  5) Custom image"
            
            while true; do
                read -p "$(print_status "INPUT" "🎯 Enter your choice (1-5): ")" image_choice
                case $image_choice in
                    1) IMAGE_NAME="ubuntu:jammy" ;;
                    2) IMAGE_NAME="debian:bullseye" ;;
                    3) IMAGE_NAME="centos:7" ;;
                    4) IMAGE_NAME="fedora:latest" ;;
                    5) 
                        read -p "$(print_status "INPUT" "🎯 Enter custom image name: ")" custom_image
                        IMAGE_NAME="$custom_image"
                        ;;
                    *) 
                        print_status "ERROR" "❌ Invalid selection"
                        continue
                        ;;
                esac
                break
            done
            ;;
        "lightweight")
            print_status "INFO" "⚡ Select a lightweight image:"
            echo "  1) Alpine Linux (latest)"
            echo "  2) Ubuntu Minimal"
            echo "  3) Debian Slim"
            echo "  4) Custom image"
            
            while true; do
                read -p "$(print_status "INPUT" "🎯 Enter your choice (1-4): ")" image_choice
                case $image_choice in
                    1) IMAGE_NAME="alpine:latest" ;;
                    2) IMAGE_NAME="ubuntu:jammy" ;;
                    3) IMAGE_NAME="debian:bullseye-slim" ;;
                    4) 
                        read -p "$(print_status "INPUT" "🎯 Enter custom image name: ")" custom_image
                        IMAGE_NAME="$custom_image"
                        ;;
                    *) 
                        print_status "ERROR" "❌ Invalid selection"
                        continue
                        ;;
                esac
                break
            done
            ;;
        "application")
            print_status "INFO" "🛠️  Select an application image:"
            echo "  1) Nginx Web Server"
            echo "  2) PostgreSQL Database"
            echo "  3) Redis Cache"
            echo "  4) Node.js Runtime"
            echo "  5) Custom image"
            
            while true; do
                read -p "$(print_status "INPUT" "🎯 Enter your choice (1-5): ")" image_choice
                case $image_choice in
                    1) IMAGE_NAME="nginx:latest" ;;
                    2) IMAGE_NAME="postgres:latest" ;;
                    3) IMAGE_NAME="redis:latest" ;;
                    4) IMAGE_NAME="node:latest" ;;
                    5) 
                        read -p "$(print_status "INPUT" "🎯 Enter custom image name: ")" custom_image
                        IMAGE_NAME="$custom_image"
                        ;;
                    *) 
                        print_status "ERROR" "❌ Invalid selection"
                        continue
                        ;;
                esac
                break
            done
            ;;
        "custom")
            read -p "$(print_status "INPUT" "🎯 Enter custom image name: ")" IMAGE_NAME
            ;;
    esac

    # Check if image exists locally, offer to pull
    if ! docker image inspect "$IMAGE_NAME" &>/dev/null; then
        print_status "WARN" "📦 Image '$IMAGE_NAME' not found locally"
        read -p "$(print_status "INPUT" "🌐 Pull image from Docker Hub? (y/N): ")" pull_choice
        if [[ "$pull_choice" =~ ^[Yy]$ ]]; then
            print_status "INFO" "⬇️  Pulling image $IMAGE_NAME..."
            docker pull "$IMAGE_NAME"
            if [ $? -ne 0 ]; then
                print_status "ERROR" "❌ Failed to pull image"
                return 1
            fi
        else
            print_status "ERROR" "❌ Cannot create container without image"
            return 1
        fi
    fi

    # Resource allocation
    print_status "INFO" "⚙️  Resource Allocation (Enter for defaults):"
    
    # Memory/RAM
    while true; do
        read -p "$(print_status "INPUT" "🧠 Memory limit (e.g., 2g, 512m) [2g]: ")" memory
        MEMORY="${memory:-2g}"
        if validate_input "size" "$MEMORY"; then
            break
        fi
    done

    # CPU
    while true; do
        read -p "$(print_status "INPUT" "⚡ CPU limit (e.g., 1.5, 2) [1]: ")" cpus
        CPUS="${cpus:-1}"
        if validate_input "number" "$CPUS"; then
            break
        fi
    done

    # Storage
    while true; do
        read -p "$(print_status "INPUT" "💾 Storage size (e.g., 20g, 100g) [20g]: ")" storage
        STORAGE="${storage:-20g}"
        if validate_input "size" "$STORAGE"; then
            break
        fi
    done

    # Network configuration
    print_status "INFO" "🌐 Network Configuration:"
    echo "  1) Bridge (default)"
    echo "  2) Host"
    echo "  3) None"
    
    while true; do
        read -p "$(print_status "INPUT" "🎯 Enter network choice (1-3) [1]: ")" net_choice
        net_choice="${net_choice:-1}"
        case $net_choice in
            1) NETWORK_MODE="bridge" ;;
            2) NETWORK_MODE="host" ;;
            3) NETWORK_MODE="none" ;;
            *) 
                print_status "ERROR" "❌ Invalid selection"
                continue
                ;;
        esac
        break
    done

    # IP configuration for bridge mode
    if [[ "$NETWORK_MODE" == "bridge" ]]; then
        while true; do
            read -p "$(print_status "INPUT" "🔢 IPv4 Address [auto]: ")" ipv4
            IPV4_ADDRESS="${ipv4:-auto}"
            if validate_input "ipv4" "$IPV4_ADDRESS"; then
                break
            fi
        done
        
        while true; do
            read -p "$(print_status "INPUT" "🔢 IPv6 Address [auto]: ")" ipv6
            IPV6_ADDRESS="${ipv6:-auto}"
            if validate_input "ipv6" "$IPV6_ADDRESS"; then
                break
            fi
        done
    else
        IPV4_ADDRESS="auto"
        IPV6_ADDRESS="auto"
    fi

    # Port mapping
    print_status "INFO" "🔌 Port Mapping (optional)"
    echo "💡 Format: HOST_PORT:CONTAINER_PORT or RANGE"
    echo "💡 Example: 80:80, 8080:8080, 3000-4000:3000-4000"
    read -p "$(print_status "INPUT" "🔌 Enter port mappings (comma separated, Enter for none): ")" PORTS
    PORTS="${PORTS:-}"

    # Volume mounts
    print_status "INFO" "💿 Volume Mounts (optional)"
    echo "💡 Format: HOST_PATH:CONTAINER_PATH[:MODE]"
    echo "💡 Example: /data:/data, ./config:/app/config:ro"
    read -p "$(print_status "INPUT" "💿 Enter volume mounts (comma separated, Enter for none): ")" VOLUMES
    VOLUMES="${VOLUMES:-}"

    # Environment variables
    print_status "INFO" "🔧 Environment Variables (optional)"
    echo "💡 Format: KEY=VALUE"
    echo "💡 Example: DB_HOST=localhost, DEBUG=true"
    read -p "$(print_status "INPUT" "🔧 Enter environment variables (comma separated, Enter for none): ")" ENV_VARS
    ENV_VARS="${ENV_VARS:-}"

    CREATED="$(date)"
    STATUS="stopped"

    # Save configuration
    save_container_config
    
    # Ask to start container now
    read -p "$(print_status "INPUT" "🚀 Start container now? (y/N): ")" start_now
    if [[ "$start_now" =~ ^[Yy]$ ]]; then
        start_container "$CONTAINER_NAME"
    fi
}

# Function to build Docker command
build_docker_command() {
    local container_name="$1"
    
    if load_container_config "$container_name"; then
        # Start building command
        local cmd="docker run -d"
        
        # Container name
        cmd="$cmd --name '$CONTAINER_NAME'"
        
        # Resource limits
        cmd="$cmd --memory='$MEMORY'"
        cmd="$cmd --cpus='$CPUS'"
        
        # Storage (using tmpfs for root filesystem)
        cmd="$cmd --tmpfs /tmp:size=$STORAGE"
        
        # Network configuration
        case "$NETWORK_MODE" in
            "host")
                cmd="$cmd --network=host"
                ;;
            "none")
                cmd="$cmd --network=none"
                ;;
            "bridge")
                cmd="$cmd --network=bridge"
                # Set IP address if specified
                if [[ "$IPV4_ADDRESS" != "auto" ]]; then
                    cmd="$cmd --ip '$IPV4_ADDRESS'"
                fi
                if [[ "$IPV6_ADDRESS" != "auto" ]]; then
                    cmd="$cmd --ip6 '$IPV6_ADDRESS'"
                fi
                ;;
        esac
        
        # Port mappings
        if [[ -n "$PORTS" ]]; then
            IFS=',' read -ra port_array <<< "$PORTS"
            for port in "${port_array[@]}"; do
                cmd="$cmd -p '$port'"
            done
        fi
        
        # Volume mounts
        if [[ -n "$VOLUMES" ]]; then
            IFS=',' read -ra volume_array <<< "$VOLUMES"
            for volume in "${volume_array[@]}"; do
                cmd="$cmd -v '$volume'"
            done
        fi
        
        # Environment variables
        if [[ -n "$ENV_VARS" ]]; then
            IFS=',' read -ra env_array <<< "$ENV_VARS"
            for env_var in "${env_array[@]}"; do
                cmd="$cmd -e '$env_var'"
            done
        fi
        
        # Additional options for systemd containers
        if [[ "$CONTAINER_TYPE" == "systemd" ]]; then
            cmd="$cmd --privileged"
            cmd="$cmd --cap-add=SYS_ADMIN"
            cmd="$cmd --cap-add=NET_ADMIN"
            cmd="$cmd --tmpfs /run"
            cmd="$cmd --tmpfs /run/lock"
            cmd="$cmd -v /sys/fs/cgroup:/sys/fs/cgroup:ro"
            cmd="$cmd -e container=docker"
            # Use systemd init
            cmd="$cmd '$IMAGE_NAME' /sbin/init"
        else
            # For non-systemd containers, run in background
            cmd="$cmd '$IMAGE_NAME'"
        fi
        
        echo "$cmd"
    fi
}

# Function to start a container
start_container() {
    local container_name=$1
    
    if load_container_config "$container_name"; then
        # Check if container is already running
        if docker ps --format '{{.Names}}' | grep -q "^$container_name$"; then
            print_status "WARN" "⚠️  Container '$container_name' is already running"
            read -p "$(print_status "INPUT" "🔄 Restart container? (y/N): ")" restart_choice
            if [[ "$restart_choice" =~ ^[Yy]$ ]]; then
                stop_container "$container_name"
                sleep 2
            else
                return 0
            fi
        fi
        
        # Check if container exists but is stopped
        if docker ps -a --format '{{.Names}}' | grep -q "^$container_name$"; then
            print_status "INFO" "🚀 Starting existing container: $container_name"
            if docker start "$container_name"; then
                STATUS="running"
                save_container_config
                print_status "SUCCESS" "✅ Container '$container_name' started"
                show_container_connection_info "$container_name"
                return 0
            else
                print_status "ERROR" "❌ Failed to start container"
                return 1
            fi
        fi
        
        # Create and start new container
        print_status "INFO" "🚀 Creating and starting container: $container_name"
        
        # Build Docker command
        local docker_cmd=$(build_docker_command "$container_name")
        
        if [[ -z "$docker_cmd" ]]; then
            print_status "ERROR" "❌ Failed to build Docker command"
            return 1
        fi
        
        # Show command
        print_status "INFO" "⚡ Executing command:"
        echo "$docker_cmd" | sed 's/--/\n  --/g'
        echo
        
        # Execute command
        if eval "$docker_cmd"; then
            STATUS="running"
            save_container_config
            print_status "SUCCESS" "✅ Container '$container_name' created and started"
            show_container_connection_info "$container_name"
            return 0
        else
            print_status "ERROR" "❌ Failed to start container"
            
            # Clean up if container creation failed
            docker rm -f "$container_name" 2>/dev/null
            return 1
        fi
    fi
}

# Function to show container connection info
show_container_connection_info() {
    local container_name=$1
    
    print_status "INFO" "🔗 Connection Information for: $container_name"
    echo "🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹"
    
    # Get container ID
    local container_id=$(docker ps -qf "name=$container_name")
    
    if [[ -n "$container_id" ]]; then
        # Get IP address
        local ip_address=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$container_name")
        
        # Get exposed ports
        local ports=$(docker port "$container_name" 2>/dev/null | tr '\n' ',' | sed 's/,$//')
        
        echo "📦 Container ID: ${container_id:0:12}"
        echo "🌐 IP Address: ${ip_address:-Not assigned}"
        
        if [[ -n "$ports" ]]; then
            echo "🔌 Ports: $ports"
        fi
        
        # Show volume mounts
        if [[ -n "$VOLUMES" ]]; then
            echo "💿 Volumes: $VOLUMES"
        fi
        
        # Show quick commands
        echo "⚡ Quick Commands:"
        echo "  📝 Enter shell: docker exec -it $container_name bash"
        echo "  📊 View logs: docker logs $container_name"
        echo "  📈 View stats: docker stats $container_name"
        
        if [[ "$CONTAINER_TYPE" == "systemd" ]]; then
            echo "  🛠️  Systemd menu: docker exec -it $container_name systemctl"
        fi
    else
        print_status "ERROR" "❌ Container not found or not running"
    fi
    
    echo "🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹"
}

# Function to stop a container
stop_container() {
    local container_name=$1
    
    if load_container_config "$container_name"; then
        # Check if container is running
        if docker ps --format '{{.Names}}' | grep -q "^$container_name$"; then
            print_status "INFO" "🛑 Stopping container: $container_name"
            
            # Ask for timeout
            read -p "$(print_status "INPUT" "⏱️  Stop timeout in seconds [10]: ")" timeout
            timeout="${timeout:-10}"
            
            if docker stop -t "$timeout" "$container_name"; then
                STATUS="stopped"
                save_container_config
                print_status "SUCCESS" "✅ Container '$container_name' stopped"
            else
                print_status "WARN" "⚠️  Failed to stop gracefully, forcing..."
                docker stop "$container_name"
                STATUS="stopped"
                save_container_config
                print_status "SUCCESS" "✅ Container '$container_name' force stopped"
            fi
        elif docker ps -a --format '{{.Names}}' | grep -q "^$container_name$"; then
            print_status "INFO" "💤 Container '$container_name' is already stopped"
            STATUS="stopped"
            save_container_config
        else
            print_status "ERROR" "❌ Container '$container_name' not found"
            return 1
        fi
    fi
}

# Function to delete a container
delete_container() {
    local container_name=$1
    
    print_status "WARN" "⚠️  ⚠️  ⚠️  This will permanently delete container '$container_name' and all its data!"
    read -p "$(print_status "INPUT" "🗑️  Are you sure? (y/N): ")" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if load_container_config "$container_name"; then
            # Check if container is running
            if docker ps --format '{{.Names}}' | grep -q "^$container_name$"; then
                print_status "WARN" "⚠️  Container is currently running. Stopping it first..."
                stop_container "$container_name"
                sleep 2
            fi
            
            # Remove container
            if docker rm "$container_name" 2>/dev/null; then
                # Remove configuration file
                rm -f "$CONTAINER_DIR/$container_name.conf"
                print_status "SUCCESS" "✅ Container '$container_name' has been deleted"
            else
                print_status "ERROR" "❌ Failed to delete container"
            fi
        fi
    else
        print_status "INFO" "👍 Deletion cancelled"
    fi
}

# Function to show container info
show_container_info() {
    local container_name=$1
    
    if load_container_config "$container_name"; then
        echo
        print_status "INFO" "📊 Container Information: $container_name"
        echo "🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹"
        echo "🐳 Image: $IMAGE_NAME"
        echo "📦 Type: $CONTAINER_TYPE"
        echo "🧠 Memory: $MEMORY"
        echo "⚡ CPUs: $CPUS"
        echo "💾 Storage: $STORAGE"
        echo "🌐 Network: $NETWORK_MODE"
        echo "🔢 IPv4: $IPV4_ADDRESS"
        echo "🔢 IPv6: $IPV6_ADDRESS"
        echo "🔌 Ports: ${PORTS:-None}"
        echo "💿 Volumes: ${VOLUMES:-None}"
        echo "🔧 Env Vars: ${ENV_VARS:-None}"
        echo "📅 Created: $CREATED"
        echo "📊 Status: $STATUS"
        
        # Get real-time status
        if docker ps --format '{{.Names}}' | grep -q "^$container_name$"; then
            echo "🚀 Current Status: Running"
            
            # Get container details
            local container_id=$(docker ps -qf "name=$container_name")
            local ip_address=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$container_name")
            local ports=$(docker port "$container_name" 2>/dev/null | tr '\n' ',' | sed 's/,$//')
            
            echo "🆔 Container ID: ${container_id:0:12}"
            echo "🌐 Current IP: ${ip_address:-Not assigned}"
            if [[ -n "$ports" ]]; then
                echo "🔌 Active Ports: $ports"
            fi
        else
            echo "💤 Current Status: Stopped"
        fi
        
        echo "🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹🔹"
        
        # Show quick actions
        echo "⚡ Quick Actions:"
        echo "  1) 📝 Enter container shell"
        echo "  2) 📊 View container logs"
        echo "  3) 📈 View container stats"
        echo "  4) 🔄 Restart container"
        echo "  5) 📋 Copy container ID"
        echo "  0) ↩️  Back"
        
        read -p "$(print_status "INPUT" "🎯 Enter your choice: ")" action_choice
        
        case $action_choice in
            1)
                enter_container_shell "$container_name"
                ;;
            2)
                view_container_logs "$container_name"
                ;;
            3)
                view_container_stats "$container_name"
                ;;
            4)
                restart_container "$container_name"
                ;;
            5)
                copy_container_id "$container_name"
                ;;
            0)
                return 0
                ;;
            *)
                print_status "ERROR" "❌ Invalid selection"
                ;;
        esac
    fi
}

# Function to enter container shell
enter_container_shell() {
    local container_name=$1
    
    if docker ps --format '{{.Names}}' | grep -q "^$container_name$"; then
        print_status "INFO" "📝 Entering container shell..."
        print_status "INFO" "💡 Type 'exit' to return to menu"
        docker exec -it "$container_name" bash || docker exec -it "$container_name" sh
    else
        print_status "ERROR" "❌ Container '$container_name' is not running"
    fi
}

# Function to view container logs
view_container_logs() {
    local container_name=$1
    
    if docker ps --format '{{.Names}}' | grep -q "^$container_name$"; then
        print_status "INFO" "📊 Showing logs for '$container_name' (Ctrl+C to exit):"
        docker logs -f --tail 50 "$container_name"
    else
        print_status "ERROR" "❌ Container '$container_name' is not running"
        # Show last logs if available
        if docker ps -a --format '{{.Names}}' | grep -q "^$container_name$"; then
            read -p "$(print_status "INPUT" "📜 Show last logs? (y/N): ")" show_logs
            if [[ "$show_logs" =~ ^[Yy]$ ]]; then
                docker logs --tail 100 "$container_name"
            fi
        fi
    fi
}

# Function to view container stats
view_container_stats() {
    local container_name=$1
    
    if docker ps --format '{{.Names}}' | grep -q "^$container_name$"; then
        print_status "INFO" "📈 Showing real-time stats for '$container_name' (Ctrl+C to exit):"
        docker stats "$container_name"
    else
        print_status "ERROR" "❌ Container '$container_name' is not running"
    fi
}

# Function to restart container
restart_container() {
    local container_name=$1
    
    if docker ps --format '{{.Names}}' | grep -q "^$container_name$"; then
        print_status "INFO" "🔄 Restarting container: $container_name"
        docker restart "$container_name"
        print_status "SUCCESS" "✅ Container '$container_name' restarted"
        sleep 2
        show_container_connection_info "$container_name"
    else
        print_status "ERROR" "❌ Container '$container_name' is not running"
    fi
}

# Function to copy container ID
copy_container_id() {
    local container_name=$1
    
    local container_id=$(docker ps -qf "name=$container_name")
    if [[ -n "$container_id" ]]; then
        if command -v xclip &>/dev/null; then
            echo -n "$container_id" | xclip -selection clipboard
            print_status "SUCCESS" "✅ Container ID copied to clipboard: ${container_id:0:12}"
        elif command -v pbcopy &>/dev/null; then
            echo -n "$container_id" | pbcopy
            print_status "SUCCESS" "✅ Container ID copied to clipboard: ${container_id:0:12}"
        else
            print_status "INFO" "📋 Container ID: $container_id"
            echo "💡 Manual copy: $container_id"
        fi
    else
        print_status "ERROR" "❌ Container '$container_name' not found"
    fi
}

# Function to edit container configuration
edit_container_config() {
    local container_name=$1
    
    if load_container_config "$container_name"; then
        print_status "INFO" "✏️  Editing container: $container_name"
        
        while true; do
            echo "📝 What would you like to edit?"
            echo "  1) 🧠 Memory (RAM)"
            echo "  2) ⚡ CPU limit"
            echo "  3) 💾 Storage size"
            echo "  4) 🔌 Port mappings"
            echo "  5) 💿 Volume mounts"
            echo "  6) 🔧 Environment variables"
            echo "  0) ↩️  Back to main menu"
            
            read -p "$(print_status "INPUT" "🎯 Enter your choice: ")" edit_choice
            
            case $edit_choice in
                1)
                    while true; do
                        read -p "$(print_status "INPUT" "🧠 Enter new memory limit (current: $MEMORY): ")" new_memory
                        new_memory="${new_memory:-$MEMORY}"
                        if validate_input "size" "$new_memory"; then
                            MEMORY="$new_memory"
                            break
                        fi
                    done
                    ;;
                2)
                    while true; do
                        read -p "$(print_status "INPUT" "⚡ Enter new CPU limit (current: $CPUS): ")" new_cpus
                        new_cpus="${new_cpus:-$CPUS}"
                        if validate_input "number" "$new_cpus"; then
                            CPUS="$new_cpus"
                            break
                        fi
                    done
                    ;;
                3)
                    while true; do
                        read -p "$(print_status "INPUT" "💾 Enter new storage size (current: $STORAGE): ")" new_storage
                        new_storage="${new_storage:-$STORAGE}"
                        if validate_input "size" "$new_storage"; then
                            STORAGE="$new_storage"
                            break
                        fi
                    done
                    ;;
                4)
                    read -p "$(print_status "INPUT" "🔌 Enter new port mappings (current: ${PORTS:-None}): ")" new_ports
                    PORTS="${new_ports:-$PORTS}"
                    ;;
                5)
                    read -p "$(print_status "INPUT" "💿 Enter new volume mounts (current: ${VOLUMES:-None}): ")" new_volumes
                    VOLUMES="${new_volumes:-$VOLUMES}"
                    ;;
                6)
                    read -p "$(print_status "INPUT" "🔧 Enter new environment variables (current: ${ENV_VARS:-None}): ")" new_env_vars
                    ENV_VARS="${new_env_vars:-$ENV_VARS}"
                    ;;
                0)
                    return 0
                    ;;
                *)
                    print_status "ERROR" "❌ Invalid selection"
                    continue
                    ;;
            esac
            
            # Save configuration
            save_container_config
            
            read -p "$(print_status "INPUT" "🔄 Continue editing? (y/N): ")" continue_editing
            if [[ ! "$continue_editing" =~ ^[Yy]$ ]]; then
                break
            fi
        done
    fi
}

# Function to check container status
is_container_running() {
    local container_name=$1
    
    if docker ps --format '{{.Names}}' | grep -q "^$container_name$"; then
        return 0
    fi
    return 1
}

# Function to show container performance
show_container_performance() {
    local container_name=$1
    
    if load_container_config "$container_name"; then
        if is_container_running "$container_name"; then
            print_status "INFO" "📊 Performance metrics for container: $container_name"
            echo "📈📈📈📈📈📈📈📈📈📈📈📈📈📈📈"
            
            # Show Docker stats
            echo "⚡ Docker Stats:"
            docker stats "$container_name" --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}"
            echo
            
            # Show process information
            echo "🔄 Container Processes:"
            docker top "$container_name"
        else
            print_status "INFO" "💤 Container $container_name is not running"
            echo "⚙️  Configuration:"
            echo "  🧠 Memory: $MEMORY"
            echo "  ⚡ CPUs: $CPUS"
            echo "  💾 Storage: $STORAGE"
        fi
        echo "📈📈📈📈📈📈📈📈📈📈📈📈📈📈📈"
        read -p "$(print_status "INPUT" "⏎ Press Enter to continue...")"
    fi
}

# Function to fix container issues
fix_container_issues() {
    local container_name=$1
    
    if load_container_config "$container_name"; then
        print_status "INFO" "🔧 Fixing issues for container: $container_name"
        
        echo "🔧 Select issue to fix:"
        echo "  1) 🔓 Force remove container (if stuck)"
        echo "  2) 🗑️  Remove all unused resources"
        echo "  3) 🔄 Restart Docker service"
        echo "  4) 📦 Recreate container from config"
        echo "  0) ↩️  Back"
        
        read -p "$(print_status "INPUT" "🎯 Enter your choice: ")" fix_choice
        
        case $fix_choice in
            1)
                print_status "WARN" "⚠️  Force removing container..."
                docker rm -f "$container_name" 2>/dev/null
                print_status "SUCCESS" "✅ Container force removed if it existed"
                ;;
            2)
                print_status "INFO" "🗑️  Cleaning up unused Docker resources..."
                docker system prune -f
                print_status "SUCCESS" "✅ Unused resources cleaned"
                ;;
            3)
                print_status "INFO" "🔄 Restarting Docker service..."
                sudo systemctl restart docker 2>/dev/null || sudo service docker restart 2>/dev/null
                print_status "SUCCESS" "✅ Docker service restarted"
                ;;
            4)
                print_status "INFO" "📦 Recreating container from configuration..."
                if docker ps -a --format '{{.Names}}' | grep -q "^$container_name$"; then
                    docker rm -f "$container_name"
                fi
                start_container "$container_name"
                ;;
            0)
                return 0
                ;;
            *)
                print_status "ERROR" "❌ Invalid selection"
                ;;
        esac
    fi
}

# Main menu function
main_menu() {
    while true; do
        display_header
        
        local containers=($(get_container_list))
        local container_count=${#containers[@]}
        
        if [ $container_count -gt 0 ]; then
            print_status "INFO" "📁 Found $container_count container(s):"
            for i in "${!containers[@]}"; do
                local status="💤"
                if is_container_running "${containers[$i]}"; then
                    status="🚀"
                fi
                printf "  %2d) %s %s\n" $((i+1)) "${containers[$i]}" "$status"
            done
            echo
        fi
        
        echo "📋 Main Menu:"
        echo "  1) 🆕 Create a new container"
        if [ $container_count -gt 0 ]; then
            echo "  2) 🚀 Start a container"
            echo "  3) 🛑 Stop a container"
            echo "  4) 📊 Show container info"
            echo "  5) ✏️  Edit container configuration"
            echo "  6) 🗑️  Delete a container"
            echo "  7) 📊 Show container performance"
            echo "  8) 🔧 Fix container issues"
        fi
        echo "  9) 📦 List all Docker containers"
        echo "  0) 👋 Exit"
        echo
        
        read -p "$(print_status "INPUT" "🎯 Enter your choice: ")" choice
        
        case $choice in
            1)
                create_new_container
                ;;
            2)
                if [ $container_count -gt 0 ]; then
                    read -p "$(print_status "INPUT" "🚀 Enter container number to start: ")" container_num
                    if [[ "$container_num" =~ ^[0-9]+$ ]] && [ "$container_num" -ge 1 ] && [ "$container_num" -le $container_count ]; then
                        start_container "${containers[$((container_num-1))]}"
                    else
                        print_status "ERROR" "❌ Invalid selection"
                    fi
                fi
                ;;
            3)
                if [ $container_count -gt 0 ]; then
                    read -p "$(print_status "INPUT" "🛑 Enter container number to stop: ")" container_num
                    if [[ "$container_num" =~ ^[0-9]+$ ]] && [ "$container_num" -ge 1 ] && [ "$container_num" -le $container_count ]; then
                        stop_container "${containers[$((container_num-1))]}"
                    else
                        print_status "ERROR" "❌ Invalid selection"
                    fi
                fi
                ;;
            4)
                if [ $container_count -gt 0 ]; then
                    read -p "$(print_status "INPUT" "📊 Enter container number to show info: ")" container_num
                    if [[ "$container_num" =~ ^[0-9]+$ ]] && [ "$container_num" -ge 1 ] && [ "$container_num" -le $container_count ]; then
                        show_container_info "${containers[$((container_num-1))]}"
                    else
                        print_status "ERROR" "❌ Invalid selection"
                    fi
                fi
                ;;
            5)
                if [ $container_count -gt 0 ]; then
                    read -p "$(print_status "INPUT" "✏️  Enter container number to edit: ")" container_num
                    if [[ "$container_num" =~ ^[0-9]+$ ]] && [ "$container_num" -ge 1 ] && [ "$container_num" -le $container_count ]; then
                        edit_container_config "${containers[$((container_num-1))]}"
                    else
                        print_status "ERROR" "❌ Invalid selection"
                    fi
                fi
                ;;
            6)
                if [ $container_count -gt 0 ]; then
                    read -p "$(print_status "INPUT" "🗑️  Enter container number to delete: ")" container_num
                    if [[ "$container_num" =~ ^[0-9]+$ ]] && [ "$container_num" -ge 1 ] && [ "$container_num" -le $container_count ]; then
                        delete_container "${containers[$((container_num-1))]}"
                    else
                        print_status "ERROR" "❌ Invalid selection"
                    fi
                fi
                ;;
            7)
                if [ $container_count -gt 0 ]; then
                    read -p "$(print_status "INPUT" "📊 Enter container number to show performance: ")" container_num
                    if [[ "$container_num" =~ ^[0-9]+$ ]] && [ "$container_num" -ge 1 ] && [ "$container_num" -le $container_count ]; then
                        show_container_performance "${containers[$((container_num-1))]}"
                    else
                        print_status "ERROR" "❌ Invalid selection"
                    fi
                fi
                ;;
            8)
                if [ $container_count -gt 0 ]; then
                    read -p "$(print_status "INPUT" "🔧 Enter container number to fix issues: ")" container_num
                    if [[ "$container_num" =~ ^[0-9]+$ ]] && [ "$container_num" -ge 1 ] && [ "$container_num" -le $container_count ]; then
                        fix_container_issues "${containers[$((container_num-1))]}"
                    else
                        print_status "ERROR" "❌ Invalid selection"
                    fi
                fi
                ;;
            9)
                print_status "INFO" "📦 All Docker containers:"
                echo "🚀 Running containers:"
                docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
                echo
                echo "💤 Stopped containers:"
                docker ps -a --filter "status=exited" --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"
                echo
                read -p "$(print_status "INPUT" "⏎ Press Enter to continue...")"
                ;;
            0)
                print_status "INFO" "👋 Goodbye!"
                exit 0
                ;;
            *)
                print_status "ERROR" "❌ Invalid option"
                ;;
        esac
        
        read -p "$(print_status "INPUT" "⏎ Press Enter to continue...")"
    done
}

# Set trap for cleanup
trap 'print_status "INFO" "👋 Exiting..."; exit 0' SIGINT

# Main execution
check_dependencies

# Initialize paths
CONTAINER_DIR="${CONTAINER_DIR:-$HOME/docker-containers}"
mkdir -p "$CONTAINER_DIR"

# Start the main menu
main_menu
