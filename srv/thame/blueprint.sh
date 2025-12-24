
#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Function to print section headers
print_header() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN} $1 ${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

# Function to print status messages
print_status() {
    echo -e "${YELLOW}⏳ $1...${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${MAGENTA}⚠️  $1${NC}"
}

# Function to check if command succeeded
check_success() {
    if [ $? -eq 0 ]; then
        print_success "$1"
        return 0
    else
        print_error "$2"
        return 1
    fi
}

# Function to animate progress
animate_progress() {
    local pid=$1
    local message=$2
    local delay=0.1
    local spinstr='|/-\'
    
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Welcome animation
welcome_animation() {
    clear
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}"
    echo "   ███╗   ██╗ ██████╗ ██████╗ ██╗████████╗ █████╗ "
    echo "   ████╗  ██║██╔═══██╗██╔══██╗██║╚══██╔══╝██╔══██╗"
    echo "   ██╔██╗ ██║██║   ██║██████╔╝██║   ██║   ███████║"
    echo "   ██║╚██╗██║██║   ██║██╔══██╗██║   ██║   ██╔══██║"
    echo "   ██║ ╚████║╚██████╔╝██║  ██║██║   ██║   ██║  ██║"
    echo "   ╚═╝  ╚═══╝ ╚═════╝ ╚═╝  ╚═╝╚═╝   ╚═╝   ╚═╝  ╚═╝"
    echo -e "${NC}"
    echo -e "${CYAN}              Blueprint Installer${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    sleep 2
}

# Function: Install (Fresh Setup)
install_nobita() {
    print_header "FRESH INSTALLATION"
    
    if [ "$EUID" -ne 0 ]; then
        print_error "Please run this script as root or with sudo"
        return 1
    fi

    print_status "Starting Fresh Install for Nobita Hosting"

    # --- Step 1: Install Node.js 20.x ---
    print_header "INSTALLING NODE.JS 20.x"
    print_status "Installing required packages"
    sudo apt-get install -y ca-certificates curl gnupg > /dev/null 2>&1 &
    animate_progress $! "Installing dependencies"
    
    print_status "Setting up Node.js repository"
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | \
      sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg > /dev/null 2>&1
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | \
      sudo tee /etc/apt/sources.list.d/nodesource.list > /dev/null 2>&1
      
    print_status "Updating package lists"
    sudo apt-get update > /dev/null 2>&1 &
    animate_progress $! "Updating package lists"
    
    print_status "Installing Node.js"
    sudo apt-get install -y nodejs > /dev/null 2>&1 &
    animate_progress $! "Installing Node.js"
    check_success "Node.js installed" "Failed to install Node.js"

    # --- Step 2: Install Yarn, Dependencies & Nobita Hosting Release ---
    print_header "INSTALLING DEPENDENCIES"
    print_status "Installing Yarn"
    npm i -g yarn > /dev/null 2>&1 &
    animate_progress $! "Installing Yarn"
    check_success "Yarn installed" "Failed to install Yarn"

    print_status "Changing to panel directory"
    cd /var/www/pterodactyl || { print_error "Panel directory not found!"; return 1; }
    
    print_status "Installing Yarn dependencies"
    yarn > /dev/null 2>&1 &
    animate_progress $! "Installing Yarn dependencies"
    check_success "Yarn dependencies installed" "Failed to install Yarn dependencies"

    print_status "Installing additional packages"
    sudo apt install -y zip unzip git curl wget > /dev/null 2>&1 &
    animate_progress $! "Installing additional packages"
    check_success "Additional packages installed" "Failed to install additional packages"

    # --- Step 3: Download and Extract Release ---
    print_header "DOWNLOADING NOBITA HOSTING"
    print_status "Downloading latest release"
    wget https://github.com/BlueprintFramework/framework/releases/download/beta-2025-11/beta-2025-11.zip
    unzip -o beta-2025-11.zip
    animate_progress $! "Downloading release"
    check_success "Release downloaded" "Failed to download release"

    print_status "Extracting release files"
    unzip -o beta-2025-11.zip > /dev/null 2>&1 &
    animate_progress $! "Extracting files"
    check_success "Files extracted" "Failed to extract files"

    # --- Step 4: Run Nobita Hosting Installer ---
    print_header "RUNNING BLUEPRINT INSTALLER"
    if [ ! -f "blueprint.sh" ]; then
        print_error "blueprint.sh not found in release package"
        return 1
    fi

    print_status "Making blueprint.sh executable"
    chmod +x blueprint.sh
    check_success "Made executable" "Failed to make executable"

    print_status "Running Blueprint installer"
    bash blueprint.sh
}

# Function: Reinstall (Rerun Only)
reinstall_nobita() {
    print_header "REINSTALLING NOBITA HOSTING"
    print_status "Starting reinstallation"
    blueprint -rerun-install > /dev/null 2>&1 &
    animate_progress $! "Reinstalling"
    check_success "Reinstallation completed" "Reinstallation failed"
}

# Function: Update Nobita Hosting
update_nobita() {
    print_header "UPDATING NOBITA HOSTING"
    print_status "Starting update"
    blueprint -upgrade > /dev/null 2>&1 &
    animate_progress $! "Updating"
    check_success "Update completed" "Update failed"
}

# Function to display the main menu
show_menu() {
    clear
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}           🔧 BLUEPRINT INSTALLER               ${NC}"
    echo -e "${CYAN}              Nobita Hosting                   ${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e ""
    echo -e "${WHITE}╔═══════════════════════════════════════════════╗${NC}"
    echo -e "${WHITE}║                📋 MAIN MENU                   ║${NC}"
    echo -e "${WHITE}╠═══════════════════════════════════════════════╣${NC}"
    echo -e "${WHITE}║   ${GREEN}1)${NC} ${CYAN}Fresh Install${NC}                         ${WHITE}║${NC}"
    echo -e "${WHITE}║   ${GREEN}2)${NC} ${CYAN}Reinstall (Rerun Only)${NC}                ${WHITE}║${NC}"
    echo -e "${WHITE}║   ${GREEN}3)${NC} ${CYAN}Update Nobita Hosting${NC}                 ${WHITE}║${NC}"
    echo -e "${WHITE}║   ${GREEN}0)${NC} ${RED}Exit${NC}                               ${WHITE}║${NC}"
    echo -e "${WHITE}╚═══════════════════════════════════════════════╝${NC}"
    echo -e ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}📝 Select an option [0-3]: ${NC}"
}

# Main execution
welcome_animation

while true; do
    show_menu
    read -r choice
    
    case $choice in
        1) install_nobita ;;
        2) reinstall_nobita ;;
        3) update_nobita ;;
        0) 
            echo -e "${GREEN}Exiting Blueprint Installer...${NC}"
            echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${CYAN}           Thank you for using our tools!       ${NC}"
            echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            sleep 2
            exit 0 
            ;;
        *) 
            print_error "Invalid option! Please choose between 0-3"
            sleep 2
            ;;
    esac
    
    echo -e ""
    read -p "$(echo -e "${YELLOW}Press Enter to continue...${NC}")" -n 1
done
