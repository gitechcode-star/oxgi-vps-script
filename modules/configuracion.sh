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

echo -e "${CYAN}SSH      :${NC} ${GREEN}$SSH_PORT,$SSH_PORT_ALT${NC}      ${CYAN}HTTP     :${NC} ${GREEN}$HTTP_PORT${NC}"

echo -e "${CYAN}HTTPS    :${NC} ${GREEN}$HTTPS_PORT${NC}          ${CYAN}WS       :${NC} ${GREEN}$WS_PORT${NC}"

echo -e "${CYAN}DROPBEAR :${NC} ${GREEN}$DROPBEAR_PORT${NC}          ${CYAN}BADVPN   :${NC} ${GREEN}$BADVPN_PORT${NC}"

echo

echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│${NC} ${WHITE}Dominio :${NC} ${YELLOW}${DOMAIN:-No Configurado}${NC}"
echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${NC}"

echo

echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${NC}"

echo -e "${CYAN}│${NC} ${GREEN}[01]${NC} ${WHITE}Nginx Manager${NC}        ${GREEN}[05]${NC} ${WHITE}BadVPN Manager${NC}"
echo -e "${CYAN}│${NC} ${GREEN}[02]${NC} ${WHITE}SSL Manager${NC}          ${GREEN}[06]${NC} ${WHITE}Firewall Manager${NC}"
echo -e "${CYAN}│${NC} ${GREEN}[03]${NC} ${WHITE}WebSocket Manager${NC}    ${GREEN}[07]${NC} ${WHITE}Puertos${NC}"
echo -e "${CYAN}│${NC} ${GREEN}[04]${NC} ${WHITE}Dropbear Manager${NC}     ${GREEN}[08]${NC} ${WHITE}Dominios${NC}"

echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${NC}"

echo

echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│${NC} ${RED}[00]${NC} ${WHITE}Regresar${NC}"
echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${NC}"

echo

read -p "$(echo -e "${YELLOW}Seleccione una opción:${NC} ")" opt

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
