#!/bin/bash

CONFIG="/etc/oxgi/config.conf"

[ -f "$CONFIG" ] && source "$CONFIG"

source /usr/local/oxgi/modules/color.sh
source /usr/local/oxgi/modules/header.sh

while true
do

[ -f "$CONFIG" ] && source "$CONFIG"

show_header

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
printf "${CYAN}│${NC} ${WHITE}Dominio : ${YELLOW}${DOMAIN:-No Configurado}${NC}"
echo
echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${NC}"

echo

echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│${NC} ${WHITE}[01]${NC} Nginx Manager        ${WHITE}[05]${NC} BadVPN Manager"
echo -e "${CYAN}│${NC} ${WHITE}[02]${NC} SSL Manager          ${WHITE}[06]${NC} Firewall Manager"
echo -e "${CYAN}│${NC} ${WHITE}[03]${NC} WebSocket Manager    ${WHITE}[07]${NC} Puertos"
echo -e "${CYAN}│${NC} ${WHITE}[04]${NC} Dropbear Manager     ${WHITE}[08]${NC} Dominios"
echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${NC}"

echo

echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│${NC} ${WHITE}[00]${NC} Regresar"
echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${NC}"

echo
read -p "Seleccione una opción: " opt

case $opt in

1|01)
bash /usr/local/oxgi/modules/nginx.sh
;;

2|02)
bash /usr/local/oxgi/modules/ssl.sh
;;

3|03)
bash /usr/local/oxgi/modules/websocket.sh
;;

4|04)
bash /usr/local/oxgi/modules/dropbear.sh
;;

5|05)
bash /usr/local/oxgi/modules/badvpn.sh
;;

6|06)
bash /usr/local/oxgi/modules/firewall.sh
;;

7|07)
bash /usr/local/oxgi/modules/puertos.sh
;;

8|08)
bash /usr/local/oxgi/modules/dominios.sh
;;

0|00)
break
;;

*)
echo
echo -e "${RED}Opción inválida${NC}"
sleep 1
;;

esac

done
