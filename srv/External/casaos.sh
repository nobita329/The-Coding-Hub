# ===================== CASAOS MENU =====================
casaos_menu(){
while true; do banner
echo -e "${C_LINE}────────────── CASAOS MENU ──────────────${NC}"
echo -e "${C_MAIN} 1) Install "
echo -e " 2) Uninstall "
echo -e " 3) Back${NC}"
echo -e "${C_LINE}────────────────────────────────────────${NC}"
read -p "Select → " cs

case $cs in
1)
  clear
  echo -e "${C_MAIN}🚀 Installing CasaOS...${NC}"
  curl -fsSL https://get.casaos.io | sudo bash
  echo
  echo -e "${C_SEC}✅ CasaOS Installed Successfully${NC}"
  echo -e "${C_SEC}🌐 Access: http://SERVER_IP:80${NC}"
  pause
;;
2)
  clear
  echo -e "${C_MAIN}🧹 Uninstalling CasaOS...${NC}"

  # Stop services
  casaos-uninstall
  systemctl stop casaos.service 2>/dev/null
  systemctl disable casaos.service 2>/dev/null

  # Remove files & dirs
  rm -rf /casaos \
         /usr/lib/casaos \
         /etc/casaos \
         /var/lib/casaos \
         /usr/bin/casaos \
         /usr/local/bin/casaos

  echo
  echo -e "${C_SEC}✅ CasaOS Completely Removed${NC}"
  pause
;;
3)
  break
;;
*)
  echo -e "${RED}Invalid Option${NC}"
  pause
;;
esac
done
}
