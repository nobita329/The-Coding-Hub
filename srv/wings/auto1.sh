# ------------------------
#  Auto-configure Wings (Auto-run)
# ------------------------
echo -e ""
echo -e "${BLUE}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
echo -e "${BLUE}┃        🚀 AUTO-CONFIGURING WINGS              ┃${NC}"
echo -e "${BLUE}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}"
echo -e ""

# Function to go back to previous input
go_back() {
    echo -e "${YELLOW}↩️  Going back to previous step...${NC}"
}

# Create backup function
backup_config() {
    local backup_dir="/etc/pterodactyl/backups"
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_file="${backup_dir}/config_backup_${timestamp}.yml"
    
    if [ -f "/etc/pterodactyl/config.yml" ]; then
        print_status "Creating backup of existing configuration"
        mkdir -p "$backup_dir"
        cp /etc/pterodactyl/config.yml "$backup_file"
        
        # Keep only last 5 backups
        ls -t "${backup_dir}/config_backup_*.yml" 2>/dev/null | tail -n +6 | xargs -r rm -f
        
        check_success "Backup created: $backup_file"
        echo -e "${CYAN}  📦 Backup saved to: ${backup_file}${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️  No existing configuration found to backup${NC}"
        return 1
    fi
}

# Create backup before any changes
echo -e "${CYAN}Creating backup of current configuration...${NC}"
backup_config

echo -e ""
echo -e "${GREEN}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
echo -e "${GREEN}┃       📝 WINGS AUTO-CONFIGURATION             ┃${NC}"
echo -e "${GREEN}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}"
echo -e ""

echo -e "${YELLOW}┌─────────────────────────────────────────────┐${NC}"
echo -e "${YELLOW}│   Please provide Pterodactyl panel details  │${NC}"
echo -e "${YELLOW}│   (type 'back' to go to previous field)     │${NC}"
echo -e "${YELLOW}└─────────────────────────────────────────────┘${NC}"
echo -e ""

# Collect configuration with back option
while true; do
    echo -ne "${CYAN}  📋 Enter UUID: ${NC}"
    read UUID
    
    if [ "$UUID" = "back" ]; then
        echo -e "${YELLOW}⚠️  Cannot go back from first field${NC}"
        continue
    elif [ -z "$UUID" ]; then
        echo -e "${RED}  ❌ UUID cannot be empty${NC}"
        continue
    else
        break
    fi
done

while true; do
    echo -ne "${CYAN}  🔑 Enter Token ID: ${NC}"
    read TOKEN_ID
    
    if [ "$TOKEN_ID" = "back" ]; then
        echo -ne "${CYAN}  📋 Enter UUID [$UUID]: ${NC}"
        read NEW_UUID
        if [ -n "$NEW_UUID" ]; then
            UUID="$NEW_UUID"
        fi
        continue
    elif [ -z "$TOKEN_ID" ]; then
        echo -e "${RED}  ❌ Token ID cannot be empty${NC}"
        continue
    else
        break
    fi
done

while true; do
    echo -ne "${CYAN}  🔒 Enter Token: ${NC}"
    read TOKEN
    
    if [ "$TOKEN" = "back" ]; then
        echo -ne "${CYAN}  🔑 Enter Token ID [$TOKEN_ID]: ${NC}"
        read NEW_TOKEN_ID
        if [ -n "$NEW_TOKEN_ID" ]; then
            TOKEN_ID="$NEW_TOKEN_ID"
        fi
        continue
    elif [ -z "$TOKEN" ]; then
        echo -e "${RED}  ❌ Token cannot be empty${NC}"
        continue
    else
        break
    fi
done

while true; do
    echo -ne "${CYAN}  🌐 Enter Panel URL (https://panel.example.com): ${NC}"
    read REMOTE
    
    if [ "$REMOTE" = "back" ]; then
        echo -ne "${CYAN}  🔒 Enter Token [$TOKEN]: ${NC}"
        read NEW_TOKEN
        if [ -n "$NEW_TOKEN" ]; then
            TOKEN="$NEW_TOKEN"
        fi
        continue
    elif [ -z "$REMOTE" ]; then
        echo -e "${YELLOW}  ⚠️  Using default URL: https://panel.example.com${NC}"
        REMOTE="https://panel.example.com"
        break
    elif [[ ! "$REMOTE" =~ ^https?:// ]]; then
        echo -e "${RED}  ❌ Please enter a valid URL starting with http:// or https://${NC}"
        continue
    else
        break
    fi
done

# Show confirmation
echo -e ""
echo -e "${CYAN}┌──────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│           📋 CONFIGURATION REVIEW                │${NC}"
echo -e "${CYAN}├──────────────────────────────────────────────────┤${NC}"
echo -e "${CYAN}│  📋 UUID:       ${UUID}${NC}"
echo -e "${CYAN}│  🔑 Token ID:   ${TOKEN_ID}${NC}"
echo -e "${CYAN}│  🌐 Panel URL:  ${REMOTE}${NC}"
echo -e "${CYAN}└──────────────────────────────────────────────────┘${NC}"
echo -e ""

# Ask for confirmation
echo -ne "${YELLOW}⚠️  Is this information correct? [Y/n/back]: ${NC}"
read CONFIRM

if [[ "$CONFIRM" =~ ^[Bb]ack$ ]]; then
    echo -e "${YELLOW}↩️  Going back to URL field...${NC}"
    while true; do
        echo -ne "${CYAN}  🌐 Enter Panel URL [$REMOTE]: ${NC}"
        read NEW_REMOTE
        if [ "$NEW_REMOTE" = "back" ]; then
            echo -e "${YELLOW}↩️  Going back to Token field...${NC}"
            while true; do
                echo -ne "${CYAN}  🔒 Enter Token [$TOKEN]: ${NC}"
                read NEW_TOKEN
                if [ "$NEW_TOKEN" = "back" ]; then
                    echo -e "${YELLOW}↩️  Going back to Token ID field...${NC}"
                    while true; do
                        echo -ne "${CYAN}  🔑 Enter Token ID [$TOKEN_ID]: ${NC}"
                        read NEW_TOKEN_ID
                        if [ "$NEW_TOKEN_ID" = "back" ]; then
                            echo -e "${YELLOW}↩️  Going back to UUID field...${NC}"
                            echo -ne "${CYAN}  📋 Enter UUID [$UUID]: ${NC}"
                            read NEW_UUID
                            if [ -n "$NEW_UUID" ]; then
                                UUID="$NEW_UUID"
                            fi
                            break
                        elif [ -n "$NEW_TOKEN_ID" ]; then
                            TOKEN_ID="$NEW_TOKEN_ID"
                            break
                        else
                            echo -e "${RED}  ❌ Token ID cannot be empty${NC}"
                        fi
                    done
                    continue
                elif [ -n "$NEW_TOKEN" ]; then
                    TOKEN="$NEW_TOKEN"
                    break
                else
                    echo -e "${RED}  ❌ Token cannot be empty${NC}"
                fi
            done
            continue
        elif [ -n "$NEW_REMOTE" ]; then
            REMOTE="$NEW_REMOTE"
            break
        else
            break
        fi
    done
elif [[ "$CONFIRM" =~ ^[Nn]$ ]]; then
    echo -e "${RED}❌ Configuration cancelled. Restoring from backup...${NC}"
    
    # Restore from backup
    local backup_dir="/etc/pterodactyl/backups"
    local latest_backup=$(ls -t "${backup_dir}/config_backup_*.yml" 2>/dev/null | head -1)
    
    if [ -f "$latest_backup" ]; then
        cp "$latest_backup" /etc/pterodactyl/config.yml
        echo -e "${GREEN}✅ Configuration restored from backup${NC}"
    fi
    
    echo -e "${YELLOW}Please run the script again with correct details.${NC}"
    exit 1
fi

echo -e ""
echo -e "${BLUE}┌─────────────────────────────────────────────┐${NC}"
echo -e "${BLUE}│     Creating Wings configuration...         │${NC}"
echo -e "${BLUE}└─────────────────────────────────────────────┘${NC}"

print_status "Creating directory structure"
mkdir -p /etc/pterodactyl

print_status "Generating config.yml"
if ! tee /etc/pterodactyl/config.yml > /dev/null <<CFG
debug: false
uuid: ${UUID}
token_id: ${TOKEN_ID}
token: ${TOKEN}
api:
  host: 0.0.0.0
  port: 8080
  ssl:
    enabled: true
    cert: /etc/certs/wing/fullchain.pem
    key: /etc/certs/wing/privkey.pem
  upload_limit: 100
system:
  data: /var/lib/pterodactyl/volumes
  sftp:
    bind_port: 2022
allowed_mounts: []
remote: '${REMOTE}'
CFG
then
    echo -e "${RED}❌ Failed to create configuration file${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Configuration saved to /etc/pterodactyl/config.yml${NC}"

echo -e ""
echo -e "${BLUE}┌─────────────────────────────────────────────┐${NC}"
echo -e "${BLUE}│         Starting Wings service...           │${NC}"
echo -e "${BLUE}└─────────────────────────────────────────────┘${NC}"

print_status "Enabling Wings service"
if ! systemctl enable wings 2>/dev/null; then
    echo -e "${YELLOW}⚠️  Could not enable Wings service (may already be enabled)${NC}"
fi

print_status "Starting Wings service"
if systemctl restart wings 2>/dev/null; then
    # Verify service is running
    sleep 3
    if systemctl is-active --quiet wings; then
        echo -e "${GREEN}✅ Wings service started successfully${NC}"
    else
        echo -e "${RED}❌ Wings service failed to start${NC}"
        echo -e "${YELLOW}Checking logs...${NC}"
        journalctl -u wings --no-pager -n 10
        exit 1
    fi
else
    echo -e "${RED}❌ Failed to start Wings service${NC}"
    exit 1
fi

echo -e ""
echo -e "${GREEN}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
echo -e "${GREEN}┃           ✅ CONFIGURATION COMPLETE           ┃${NC}"
echo -e "${GREEN}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}"
echo -e ""

# Quick reference
echo -e ""
echo -e "${BLUE}┌─────────────────────────────────────────────┐${NC}"
echo -e "${BLUE}│              🛠️  QUICK COMMANDS              │${NC}"
echo -e "${BLUE}└─────────────────────────────────────────────┘${NC}"
echo -e "${CYAN}  🔍 Check status:  ${GREEN}systemctl status wings${NC}"
echo -e "${CYAN}  📋 View logs:     ${GREEN}journalctl -u wings -f${NC}"
echo -e "${CYAN}  🔄 Restart:       ${GREEN}systemctl restart wings${NC}"
echo -e "${CYAN}  📂 Config edit:   ${GREEN}nano /etc/pterodactyl/config.yml${NC}"
echo -e "${CYAN}  💾 List backups:  ${GREEN}ls -la /etc/pterodactyl/backups/${NC}"

echo -e ""
echo -e "${BLUE}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
echo -e "${BLUE}┃        🌟 THANK YOU FOR CHOOSING             ┃${NC}"
echo -e "${BLUE}┃           Nobita-hosting!                    ┃${NC}"
echo -e "${BLUE}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}"
echo -e ""
