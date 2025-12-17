#!/bin/bash

CONFIG_FILE="/etc/pterodactyl/config.yml"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}⚙️ Applying Wings config (separate blocks)...${NC}"

# Create file if missing
[ ! -f "$CONFIG_FILE" ] && touch "$CONFIG_FILE"

# Backup
cp "$CONFIG_FILE" "${CONFIG_FILE}.bak.$(date +%F-%T)"

# ===== HOST =====
sed -i '/^host:/d' "$CONFIG_FILE"
echo "host: 0.0.0.0" >> "$CONFIG_FILE"

# ===== PORT =====
sed -i '/^port:/d' "$CONFIG_FILE"
echo "port: 8080" >> "$CONFIG_FILE"

# ===== SSL =====
sed -i '/^ssl:/,/^[^ ]/d' "$CONFIG_FILE"

cat <<'EOF' >> "$CONFIG_FILE"
ssl:
  enabled: true
  cert: /etc/certs/wing/fullchain.pem
  key: /etc/certs/wing/privkey.pem
EOF

# ===== Restart Wings =====
systemctl restart wings

echo -e "${GREEN}
✅ Wings config applied successfully
- Host : 0.0.0.0
- Port : 8080
- SSL  : Enabled
${NC}"
