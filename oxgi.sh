#!/bin/bash

CONFIG="/etc/oxgi/config.conf"
VERSION_FILE="/etc/oxgi/version.conf"

[ -f "$CONFIG" ] && source "$CONFIG"
[ -f "$VERSION_FILE" ] && source "$VERSION_FILE"

source /usr/local/oxgi/modules/color.sh
source /usr/local/oxgi/modules/header.sh

while true
do

[ -f "$CONFIG" ] && source "$CONFIG"
[ -f "$VERSION_FILE" ] && source "$VERSION_FILE"

show_header

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
echo -e "${CYAN}│${NC} ${WHITE}[ SSH : ${GREEN}ON${WHITE} ]   [ XRAY : ${GREEN}ON${WHITE} ]   [ NGINX : ${GREEN}ON${WHITE} ]${NC}"
echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${NC}"

echo

echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│${NC} ${WHITE}[01]${NC} SSH Manager        ${WHITE}[04]${NC} Configuración"
echo -e "${CYAN}│${NC} ${WHITE}[02]${NC} V2Ray Manager      ${WHITE}[05]${NC} Actualizar Script"
echo -e "${CYAN}│${NC} ${WHITE}[03]${NC} Monitor"
echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${NC}"

echo

echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│${NC} ${RED}[00]${NC} Exit"
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
echo -e "${GREEN}Gracias por usar OXGI VPS${NC}"
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
