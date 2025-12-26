#!/bin/bash

# ============================================
# LXC/LXD Management Script
# Version: 2.0
# Author: LXC Manager
# ============================================

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to print header
print_header() {
    clear
    echo "╔══════════════════════════════════════════╗"
    echo "║         LXC/LXD Container Manager        ║"
    echo "╚══════════════════════════════════════════╝"
    echo
}

# OS Image Database
declare -A OS_IMAGES=(
    ["1"]="ubuntu:22.04|Ubuntu 22.04 Jammy"
    ["2"]="almalinux/9|AlmaLinux 9"
    ["3"]="centos/stream-9|CentOS Stream 9"
    ["4"]="ubuntu:24.04|Ubuntu 24.04 Noble"
    ["5"]="rockylinux/9|Rocky Linux 9"
    ["6"]="fedora/40|Fedora 40"
    ["7"]="debian/11|Debian 11 Bullseye"
    ["8"]="debian/trixie-daily|Debian 13 Trixie (Daily)"
    ["9"]="debian/12|Debian 12 Bookworm"
)

# Alternative image sources
declare -A ALT_IMAGES=(
    ["debian/13"]="images:debian/trixie"
    ["ubuntu/noble"]="images:ubuntu/24.04"
    ["ubuntu/jammy"]="images:ubuntu/22.04"
    ["rockylinux/9"]="images:rockylinux/9"
    ["almalinux/9"]="images:almalinux/9"
    ["centos/9"]="images:centos/9"
    ["fedora/40"]="images:fedora/40"
)

# Function to show image selection menu
show_image_menu() {
    print_header
    print_color "$CYAN" "📦 Available Container Images"
    echo "══════════════════════════════════════════"
    echo
    
    for key in {1..9}; do
        if [[ -n "${OS_IMAGES[$key]}" ]]; then
            IFS='|' read -r image_name display_name <<< "${OS_IMAGES[$key]}"
            print_color "$GREEN" "  $key) $display_name"
            print_color "$BLUE" "     📦 Image: $image_name"
            echo
        fi
    done
    
    echo "══════════════════════════════════════════"
    echo "  0) ↩️  Back to Main Menu"
    echo
}

# Function to install dependencies
install_dependencies() {
    print_header
    print_color "$CYAN" "🔧 Installing Dependencies..."
    echo "══════════════════════════════════════════"
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        print_color "$YELLOW" "⚠️  Running as root. Some operations might need user permissions."
    fi
    
    # Detect distribution
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        OS_NAME=$ID
    else
        print_color "$RED" "❌ Cannot detect OS distribution!"
        exit 1
    fi
    
    print_color "$BLUE" "📊 Detected: $PRETTY_NAME"
    echo
    
    case $OS_NAME in
        ubuntu|debian)
            print_color "$GREEN" "📦 Installing for Ubuntu/Debian..."
            echo
            
            # Update package lists
            print_color "$CYAN" "🔄 Updating package lists..."
            sudo apt update -y
            
            # Install LXC
            print_color "$CYAN" "📥 Installing LXC..."
            sudo apt install -y lxc lxc-utils lxc-templates bridge-utils uidmap
            
            # Install and configure snapd for LXD
            if ! command -v snap &> /dev/null; then
                print_color "$CYAN" "📦 Installing snapd..."
                sudo apt install -y snapd
                sudo systemctl enable --now snapd.socket
                sudo ln -s /var/lib/snapd/snap /snap 2>/dev/null || true
            fi
            
            # Install LXD
            print_color "$CYAN" "🚀 Installing LXD..."
            sudo snap install lxd
            
            # Add user to lxd group
            print_color "$CYAN" "👤 Adding user to lxd group..."
            sudo usermod -aG lxd $USER
            
            # Initialize LXD
            print_color "$CYAN" "⚙️  Initializing LXD..."
            sudo lxd init --auto
            
            print_color "$GREEN" "✅ Dependencies installed successfully!"
            echo
            print_color "$YELLOW" "⚠️  Please log out and log back in for group changes!"
            ;;
        *)
            print_color "$RED" "❌ Unsupported OS: $OS_NAME"
            print_color "$YELLOW" "📋 Manual installation required:"
            echo "For Ubuntu/Debian:"
            echo "  sudo apt install lxc lxc-utils bridge-utils snapd"
            echo "  sudo snap install lxd"
            echo "  sudo usermod -aG lxd \$USER"
            echo "  sudo lxd init --auto"
            ;;
    esac
    
    read -p "⏎ Press Enter to continue..."
}

# Function to check installation
check_installation() {
    print_header
    print_color "$CYAN" "🔍 Checking Installation..."
    echo "══════════════════════════════════════════"
    echo
    
    local checks_passed=0
    local total_checks=4
    
    # Check LXC
    if command -v lxc &> /dev/null; then
        print_color "$GREEN" "✅ LXC is installed"
        ((checks_passed++))
    else
        print_color "$RED" "❌ LXC is NOT installed"
    fi
    
    # Check LXD
    if command -v lxd &> /dev/null; then
        print_color "$GREEN" "✅ LXD is installed"
        ((checks_passed++))
    else
        print_color "$RED" "❌ LXD is NOT installed"
    fi
    
    # Check if user is in lxd group
    if groups $USER | grep -q '\blxd\b'; then
        print_color "$GREEN" "✅ User is in lxd group"
        ((checks_passed++))
    else
        print_color "$YELLOW" "⚠️  User is NOT in lxd group"
    fi
    
    # Check LXD service
    if systemctl is-active --quiet snap.lxd.daemon 2>/dev/null || systemctl is-active --quiet lxd 2>/dev/null; then
        print_color "$GREEN" "✅ LXD service is running"
        ((checks_passed++))
    else
        print_color "$RED" "❌ LXD service is NOT running"
    fi
    
    echo
    print_color "$BLUE" "📊 Status: $checks_passed/$total_checks checks passed"
    
    if [[ $checks_passed -eq $total_checks ]]; then
        print_color "$GREEN" "🎉 All systems go! LXC/LXD is ready."
    elif [[ $checks_passed -ge 2 ]]; then
        print_color "$YELLOW" "⚠️  Some issues detected. Consider reinstalling."
    else
        print_color "$RED" "🚨 Major issues detected. Please reinstall dependencies."
    fi
    
    read -p "⏎ Press Enter to continue..."
}

# Function to list containers
list_containers() {
    print_header
    print_color "$CYAN" "📋 Container List"
    echo "══════════════════════════════════════════"
    echo
    
    if ! command -v lxc &> /dev/null; then
        print_color "$RED" "❌ LXC is not installed!"
        read -p "⏎ Press Enter to continue..."
        return
    fi
    
    # List all containers with formatting
    lxc list
    
    echo
    print_color "$YELLOW" "📊 Legend:"
    echo "  🟢 RUNNING - Container is active"
    echo "  🔴 STOPPED - Container is not running"
    echo "  ⚪ FROZEN  - Container is paused"
    echo "  🟡 ERROR   - Container has issues"
    
    read -p "⏎ Press Enter to continue..."
}

# Function to create container from selected image
create_container() {
    while true; do
        show_image_menu
        read -p "🎯 Select image (1-9) or 0 to cancel: " image_choice
        
        if [[ "$image_choice" == "0" ]]; then
            return
        fi
        
        if [[ -n "${OS_IMAGES[$image_choice]}" ]]; then
            IFS='|' read -r image_name display_name <<< "${OS_IMAGES[$image_choice]}"
            break
        else
            print_color "$RED" "❌ Invalid selection!"
            sleep 2
        fi
    done
    
    print_header
    print_color "$CYAN" "🚀 Creating Container: $display_name"
    echo "══════════════════════════════════════════"
    echo
    
    # Get container name
    while true; do
        read -p "🏷️  Enter container name: " container_name
        if [[ -z "$container_name" ]]; then
            print_color "$RED" "❌ Container name cannot be empty!"
            continue
        fi
        
        # Check if container already exists
        if lxc list -c n --format csv 2>/dev/null | grep -q "^$container_name$"; then
            print_color "$RED" "❌ Container '$container_name' already exists!"
            continue
        fi
        
        # Validate name
        if [[ ! "$container_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            print_color "$RED" "❌ Invalid name! Use only letters, numbers, hyphens, and underscores."
            continue
        fi
        
        break
    done
    
    # Get container type
    echo
    print_color "$YELLOW" "💻 Container Type:"
    echo "  1) Container (Default) - Lightweight, shares host kernel"
    echo "  2) Virtual Machine - Full VM with its own kernel"
    read -p "Select type (1-2, default: 1): " container_type
    container_type=${container_type:-1}
    
    local type_flag=""
    case $container_type in
        1) type_flag="" ;;
        2) type_flag="--vm" ;;
        *) type_flag="" ;;
    esac
    
    # Get resources
    echo
    print_color "$YELLOW" "⚙️  Resource Configuration:"
    read -p "💾 Disk size (e.g., 10GB, default: 10GB): " disk_size
    disk_size=${disk_size:-10GB}
    
    read -p "🧠 Memory (e.g., 2GB, default: 2GB): " memory
    memory=${memory:-2GB}
    
    read -p "⚡ CPU cores (default: 2): " cpu_count
    cpu_count=${cpu_count:-2}
    
    # Create container
    print_color "$BLUE" "📦 Creating container '$container_name' from '$image_name'..."
    echo
    
    # Try to launch with images: prefix first
    local launch_cmd="lxc launch $type_flag images:$image_name $container_name"
    
    # Execute launch command
    if eval $launch_cmd; then
        print_color "$GREEN" "✅ Container created successfully!"
    else
        print_color "$YELLOW" "⚠️  Trying alternative image source..."
        
        # Try alternative sources
        local alt_image=""
        for key in "${!ALT_IMAGES[@]}"; do
            if [[ "$image_name" == *"$key"* ]]; then
                alt_image="${ALT_IMAGES[$key]}"
                break
            fi
        done
        
        if [[ -n "$alt_image" ]]; then
            launch_cmd="lxc launch $type_flag $alt_image $container_name"
            if eval $launch_cmd; then
                print_color "$GREEN" "✅ Container created using alternative source!"
            else
                print_color "$RED" "❌ Failed to create container!"
                read -p "⏎ Press Enter to continue..."
                return
            fi
        else
            print_color "$RED" "❌ Failed to create container!"
            read -p "⏎ Press Enter to continue..."
            return
        fi
    fi
    
    # Set resource limits
    print_color "$BLUE" "⚙️  Configuring resources..."
    lxc config set $container_name limits.cpu=$cpu_count 2>/dev/null || true
    lxc config set $container_name limits.memory=$memory 2>/dev/null || true
    
    # Wait for container to be ready
    print_color "$BLUE" "⏳ Waiting for container to initialize..."
    sleep 5
    
    # Show container info
    echo
    print_color "$CYAN" "📊 Container Information:"
    echo "──────────────────────────────────────"
    lxc list $container_name
    
    # Get IP address if available
    local container_ip=$(lxc list $container_name -c 4 --format csv | head -1)
    
    echo
    print_color "$GREEN" "🎉 Container '$container_name' is ready!"
    
    if [[ -n "$container_ip" && "$container_ip" != "-" ]]; then
        print_color "$BLUE" "🌐 IP Address: $container_ip"
    fi
    
    # Show connection info based on OS
    case $image_name in
        ubuntu:*|debian:*)
            print_color "$YELLOW" "🔑 Default credentials:"
            echo "  Username: ubuntu (for Ubuntu)"
            echo "  Username: debian (for Debian)"
            echo "  Password: (none - use SSH key or set password)"
            echo
            print_color "$CYAN" "💻 Connect via SSH:"
            echo "  ssh ubuntu@$container_ip"
            ;;
        centos*|rockylinux*|almalinux*|fedora*)
            print_color "$YELLOW" "🔑 Default credentials:"
            echo "  Username: root"
            echo "  Password: (set during first boot)"
            echo
            print_color "$CYAN" "💻 Connect via SSH:"
            echo "  ssh root@$container_ip"
            ;;
    esac
    
    echo
    read -p "⏎ Press Enter to continue..."
}

# Function to manage containers
manage_container() {
    print_header
    print_color "$CYAN" "⚙️  Container Management"
    echo "══════════════════════════════════════════"
    echo
    
    if ! command -v lxc &> /dev/null; then
        print_color "$RED" "❌ LXC is not installed!"
        read -p "⏎ Press Enter to continue..."
        return
    fi
    
    # Get container list
    local containers=$(lxc list -c n --format csv 2>/dev/null)
    if [[ -z "$containers" ]]; then
        print_color "$YELLOW" "📭 No containers found!"
        read -p "⏎ Press Enter to continue..."
        return
    fi
    
    # Display containers
    print_color "$BLUE" "📋 Available Containers:"
    echo
    local i=1
    declare -A container_map
    for container in $containers; do
        container_map[$i]=$container
        local status=$(lxc list $container -c s --format csv 2>/dev/null)
        local status_icon="🔴"
        [[ "$status" == "RUNNING" ]] && status_icon="🟢"
        [[ "$status" == "FROZEN" ]] && status_icon="⚪"
        echo "  $i) $status_icon $container"
        ((i++))
    done
    
    echo
    read -p "🎯 Select container number: " container_num
    
    if [[ -z "${container_map[$container_num]}" ]]; then
        print_color "$RED" "❌ Invalid selection!"
        read -p "⏎ Press Enter to continue..."
        return
    fi
    
    local container_name=${container_map[$container_num]}
    local container_status=$(lxc list $container_name -c s --format csv 2>/dev/null)
    
    while true; do
        print_header
        print_color "$CYAN" "⚙️  Managing: $container_name"
        print_color "$BLUE" "📊 Status: $container_status"
        echo "══════════════════════════════════════════"
        echo
        
        print_color "$YELLOW" "📋 Operations:"
        echo "  1) ▶️  Start Container"
        echo "  2) ⏹️  Stop Container"
        echo "  3) 🔄 Restart Container"
        echo "  4) ⏸️  Pause/Freeze"
        echo "  5) ⏯️  Resume/Unfreeze"
        echo "  6) 💻 Open Shell"
        echo "  7) 📊 Show Info"
        echo "  8) 📝 View Logs"
        echo "  9) ⚙️  Configure"
        echo "  10) 🗑️  Delete"
        echo "  0) ↩️  Back"
        echo
        
        read -p "🎯 Select operation: " operation
        
        case $operation in
            1)
                print_color "$GREEN" "▶️  Starting container..."
                lxc start $container_name
                container_status="RUNNING"
                read -p "⏎ Press Enter to continue..."
                ;;
            2)
                print_color "$YELLOW" "⏹️  Stopping container..."
                lxc stop $container_name
                container_status="STOPPED"
                read -p "⏎ Press Enter to continue..."
                ;;
            3)
                print_color "$BLUE" "🔄 Restarting container..."
                lxc restart $container_name
                container_status="RUNNING"
                read -p "⏎ Press Enter to continue..."
                ;;
            4)
                print_color "$PURPLE" "⏸️  Freezing container..."
                lxc freeze $container_name
                container_status="FROZEN"
                read -p "⏎ Press Enter to continue..."
                ;;
            5)
                print_color "$PURPLE" "⏯️  Unfreezing container..."
                lxc unfreeze $container_name
                container_status="RUNNING"
                read -p "⏎ Press Enter to continue..."
                ;;
            6)
                print_color "$CYAN" "💻 Opening shell..."
                echo "📝 Type 'exit' to return to menu"
                lxc exec $container_name -- /bin/bash
                ;;
            7)
                print_color "$BLUE" "📊 Container Information:"
                lxc info $container_name
                echo
                read -p "⏎ Press Enter to continue..."
                ;;
            8)
                print_color "$BLUE" "📝 Container Logs:"
                lxc info $container_name --show-log | head -50
                read -p "⏎ Press Enter to continue..."
                ;;
            9)
                configure_container $container_name
                ;;
            10)
                print_color "$RED" "⚠️  ⚠️  ⚠️  WARNING: This will delete the container!"
                read -p "🗑️  Are you sure? (y/N): " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    lxc delete $container_name --force
                    print_color "$GREEN" "✅ Container deleted!"
                    read -p "⏎ Press Enter to continue..."
                    return
                fi
                ;;
            0)
                return
                ;;
            *)
                print_color "$RED" "❌ Invalid operation!"
                read -p "⏎ Press Enter to continue..."
                ;;
        esac
    done
}

# Function to configure container
configure_container() {
    local container_name=$1
    
    while true; do
        print_header
        print_color "$CYAN" "⚙️  Configuring: $container_name"
        echo "══════════════════════════════════════════"
        echo
        
        print_color "$YELLOW" "📋 Configuration Options:"
        echo "  1) ⚡ Set CPU Limits"
        echo "  2) 🧠 Set Memory Limits"
        echo "  3) 💾 Set Disk Limits"
        echo "  4) 🔧 Add Device"
        echo "  5) 🌐 Network Settings"
        echo "  6) 🔒 Security Settings"
        echo "  7) 👁️  View Configuration"
        echo "  0) ↩️  Back"
        echo
        
        read -p "🎯 Select option: " config_opt
        
        case $config_opt in
            1)
                read -p "⚡ Enter CPU limit (e.g., 2 or 0-4): " cpu_limit
                lxc config set $container_name limits.cpu="$cpu_limit"
                print_color "$GREEN" "✅ CPU limit set to: $cpu_limit"
                ;;
            2)
                read -p "🧠 Enter memory limit (e.g., 2GB or 512MB): " mem_limit
                lxc config set $container_name limits.memory="$mem_limit"
                print_color "$GREEN" "✅ Memory limit set to: $mem_limit"
                ;;
            3)
                read -p "💾 Enter disk limit (e.g., 20GB): " disk_limit
                lxc config device set $container_name root size="$disk_limit"
                print_color "$GREEN" "✅ Disk limit set to: $disk_limit"
                ;;
            4)
                echo "🔧 Available device types: disk, nic, unix-char, gpu"
                read -p "Device name: " dev_name
                read -p "Device type: " dev_type
                read -p "Source path: " dev_source
                read -p "Destination path: " dev_dest
                lxc config device add $container_name $dev_name $dev_type source=$dev_source path=$dev_dest
                ;;
            5)
                echo "🌐 Available networks:"
                lxc network list
                read -p "Network name (default: lxdbr0): " net_name
                net_name=${net_name:-lxdbr0}
                lxc network attach $net_name $container_name eth0
                print_color "$GREEN" "✅ Attached to network: $net_name"
                ;;
            6)
                echo "🔒 Security options:"
                read -p "Enable nesting? (true/false): " nesting_val
                lxc config set $container_name security.nesting=$nesting_val
                ;;
            7)
                print_color "$BLUE" "👁️  Current Configuration:"
                lxc config show $container_name
                ;;
            0)
                return
                ;;
            *)
                print_color "$RED" "❌ Invalid option!"
                ;;
        esac
        
        read -p "⏎ Press Enter to continue..."
    done
}

# Function to show system info
show_system_info() {
    print_header
    print_color "$CYAN" "📊 System Information"
    echo "══════════════════════════════════════════"
    echo
    
    # LXC/LXD Info
    print_color "$YELLOW" "🚀 LXC/LXD Information:"
    echo "──────────────────────────────────────"
    if command -v lxc-version &> /dev/null; then
        echo -n "📦 LXC Version: "
        lxc-version | head -1
    fi
    
    if command -v lxd &> /dev/null; then
        echo -n "📦 LXD Version: "
        lxd --version 2>/dev/null || echo "Snap version"
    fi
    
    # Container count
    if command -v lxc &> /dev/null; then
        local container_count=$(lxc list --format csv 2>/dev/null | wc -l)
        echo "📦 Containers: $container_count"
    fi
    
    # System Info
    echo
    print_color "$YELLOW" "💻 System Information:"
    echo "──────────────────────────────────────"
    
    # OS info
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        echo "🏷️  OS: $PRETTY_NAME"
    fi
    
    # Kernel
    echo "🐧 Kernel: $(uname -r)"
    
    # CPU
    echo "⚡ CPU: $(nproc) cores"
    echo "💾 Memory: $(free -h | awk '/^Mem:/ {print $2}') total"
    echo "💿 Disk: $(df -h / | awk 'NR==2 {print $4}') free"
    
    echo
    read -p "⏎ Press Enter to continue..."
}

# Function to list available images
list_images() {
    print_header
    print_color "$CYAN" "📦 Available Images"
    echo "══════════════════════════════════════════"
    echo
    
    print_color "$BLUE" "🌟 Pre-configured Images:"
    echo "──────────────────────────────────────"
    
    for key in {1..9}; do
        if [[ -n "${OS_IMAGES[$key]}" ]]; then
            IFS='|' read -r image_name display_name <<< "${OS_IMAGES[$key]}"
            echo "🔹 $display_name"
            echo "   📦 lxc launch images:$image_name <name>"
            echo
        fi
    done
    
    echo "══════════════════════════════════════════"
    echo
    print_color "$YELLOW" "📝 To list all available remote images:"
    echo "  lxc image list images:"
    echo
    print_color "$YELLOW" "📝 To search for specific images:"
    echo "  lxc image list images: | grep ubuntu"
    echo "  lxc image list images: | grep debian"
    
    read -p "⏎ Press Enter to continue..."
}

# Main menu
main_menu() {
    while true; do
        print_header
        print_color "$GREEN" "📋 Main Menu"
        echo "══════════════════════════════════════════"
        echo
        
        # Get container count
        local container_count=0
        if command -v lxc &> /dev/null; then
            container_count=$(lxc list --format csv 2>/dev/null | wc -l)
        fi
        
        print_color "$BLUE" "📦 Containers: $container_count"
        echo
        
        echo "  1) 🔧 Install Dependencies"
        echo "  2) ✅ Check Installation"
        echo "  3) 📦 List Available Images"
        echo "  4) 🚀 Create Container"
        echo "  5) 📋 List Containers"
        echo "  6) ⚙️  Manage Container"
        echo "  7) 📊 System Information"
        echo "  0) 👋 Exit"
        echo
        
        read -p "🎯 Select option: " choice
        
        case $choice in
            1) install_dependencies ;;
            2) check_installation ;;
            3) list_images ;;
            4) create_container ;;
            5) list_containers ;;
            6) manage_container ;;
            7) show_system_info ;;
            0)
                print_header
                print_color "$GREEN" "👋 Goodbye!"
                echo
                exit 0
                ;;
            *)
                print_color "$RED" "❌ Invalid option!"
                sleep 1
                ;;
        esac
    done
}

# Check if LXC is available
check_lxc_availability() {
    if ! command -v lxc &> /dev/null; then
        print_header
        print_color "$YELLOW" "⚠️  LXC/LXD Not Detected"
        echo "══════════════════════════════════════════"
        echo
        print_color "$CYAN" "This script requires LXC/LXD to be installed."
        echo "Would you like to install it now?"
        echo
        
        read -p "📦 Install dependencies? (Y/n): " install_choice
        install_choice=${install_choice:-Y}
        
        if [[ "$install_choice" =~ ^[Yy]$ ]]; then
            install_dependencies
        else
            print_color "$YELLOW" "⚠️  LXC/LXD is required for this script."
            echo "You can install it manually using option 1."
            sleep 2
        fi
    fi
}

# Main function
main() {
    # Check if in terminal
    if [[ ! -t 0 ]]; then
        print_color "$RED" "❌ This script must be run in a terminal!"
        exit 1
    fi
    
    # Welcome
    print_header
    print_color "$GREEN" "🌟 Welcome to LXC/LXD Container Manager"
    echo
    print_color "$CYAN" "📦 Manage lightweight containers with ease"
    echo
    
    # Check LXC
    check_lxc_availability
    
    # Start main menu
    main_menu
}

# Run main
main
