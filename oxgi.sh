#!/bin/bash

CONFIG="/etc/oxgi/config.conf"
VERSION_FILE="/etc/oxgi/version.conf"

[ -f "$CONFIG" ] && source "$CONFIG"
[ -f "$VERSION_FILE" ] && source "$VERSION_FILE"

source /usr/local/oxgi/modules/header.sh

BLUE='\033[1;34m'
CYAN='\033[1;36m'
GREEN='\033[1;32m'
WHITE='\033[1;37m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m'

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
echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
echo

echo -e "${GREEN}[1]${NC} SSH Manager"
echo -e "${GREEN}[2]${NC} V2Ray Manager"
echo -e "${GREEN}[3]${NC} Monitor"

echo
echo -e "${CYAN}[4]${NC} Configuración"
echo -e "${CYAN}[5]${NC} Actualizar Script"

echo
echo -e "${RED}[0]${NC} Exit"

echo
echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
echo

read -p "Seleccione una opción: " opt

case $opt in

1)
bash /usr/local/oxgi/modules/ssh.sh
;;

2)
bash /usr/local/oxgi/modules/v2ray.sh
;;

3)
bash /usr/local/oxgi/modules/monitor.sh
;;

4)
bash /usr/local/oxgi/modules/configuracion.sh
;;

5)
bash /usr/local/oxgi/modules/updater.sh
;;

0)
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
