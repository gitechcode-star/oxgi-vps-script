#!/bin/bash

CONFIG="/etc/oxgi/config.conf"
VERSION_FILE="/etc/oxgi/version.conf"

[ -f "$CONFIG" ] && source "$CONFIG"
[ -f "$VERSION_FILE" ] && source "$VERSION_FILE"

CYAN="\e[1;36m"
GREEN="\e[1;32m"
RED="\e[1;31m"
WHITE="\e[1;37m"
YELLOW="\e[1;33m"
NC="\e[0m"

while true
do

[ -f "$CONFIG" ] && source "$CONFIG"
[ -f "$VERSION_FILE" ] && source "$VERSION_FILE"

clear

echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${NC}"
printf "${CYAN}│${NC} %-58s ${CYAN}│${NC}\n" \
"${WHITE}${APP_NAME} - Versión : ${VERSION} - (${AUTHOR})${NC}"
echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${NC}"

echo

printf "${WHITE}%-30s %-30s${NC}\n" \
"SSH      : $SSH_PORT,$SSH_PORT_ALT" \
"HTTP     : $HTTP_PORT"

printf "${WHITE}%-30s %-30s${NC}\n" \
"HTTPS    : $HTTPS_PORT" \
"WS       : $WS_PORT"

printf "${WHITE}%-30s %-30s${NC}\n" \
"DROPBEAR : $DROPBEAR_PORT" \
"BADVPN   : $BADVPN_PORT"

echo
echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${NC}"
printf "${CYAN}│${NC} ${WHITE}[ SSH : ${GREEN}ON${WHITE} ]   [ XRAY : ${GREEN}ON${WHITE} ]   [ NGINX : ${GREEN}ON${WHITE} ]${NC}"
echo
echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${NC}"

echo

echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│${NC} ${WHITE}[01]${NC} SSH Manager        ${WHITE}[04]${NC} Configuración"
echo -e "${CYAN}│${NC} ${WHITE}[02]${NC} V2Ray Manager      ${WHITE}[05]${NC} Actualizar Script"
echo -e "${CYAN}│${NC} ${WHITE}[03]${NC} Monitor"
echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${NC}"

echo

echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│${NC} ${WHITE}[00]${NC} Exit"
echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${NC}"

echo
read -p "Seleccione una opción: " opt

case $opt in

1|01)
bash /usr/local/oxgi/modules/ssh.sh
;;

2|02)
bash /usr/local/oxgi/modules/v2ray.sh
;;

3|03)
bash /usr/local/oxgi/modules/monitor.sh
;;

4|04)
bash /usr/local/oxgi/modules/configuracion.sh
;;

5|05)
bash /usr/local/oxgi/modules/updater.sh
;;

0|00)
clear
echo
echo "Gracias por usar OXGI VPS"
echo
exit 0
;;

*)
echo
echo -e "${RED}Opción inválida${NC}"
sleep 1
;;

esac

done
