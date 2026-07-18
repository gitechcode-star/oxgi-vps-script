#!/bin/bash
source /etc/oxgi/config.conf
source /usr/local/oxgi/modules/color.sh

clear
echo -e "${CYAN}┌────────────────────────────────────┐${NC}"
echo -e "${CYAN}│     ${BOLD}CREAR CUENTA SSH${NC}"
echo -e "${CYAN}└────────────────────────────────────┘${NC}"
echo

read -p "Username: " LOGIN
read -p "Password: " PASSWORD
read -p "Days Active: " EXP

useradd -e `date -d "$EXP days" +"%Y-%m-%d"` -s /bin/false -M $LOGIN
echo -e "$PASSWORD\n$PASSWORD" | passwd $LOGIN &> /dev/null

echo -e "${OKEY} Cuenta creada exitosamente!"
echo -e "${INFO} Username: ${GREEN}$LOGIN${NC}"
echo -e "${INFO} Password: ${GREEN}$PASSWORD${NC}"
echo -e "${INFO} Expira: ${GREEN}`date -d "$EXP days" +"%Y-%m-%d"`${NC}"
echo
read -p "Presione ENTER para continuar..."
