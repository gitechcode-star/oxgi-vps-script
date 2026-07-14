#!/bin/bash

source /usr/local/oxgi/modules/color.sh
source /usr/local/oxgi/modules/header.sh

while true
do

show_header

echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${NC}"
printf "${CYAN}│${NC} %-58s ${CYAN}│${NC}\n" "${WHITE}XRAY / V2RAY MANAGER${NC}"
echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${NC}"

echo

echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${NC}"
printf "${CYAN}│${NC} ${WHITE}[01]${NC} Crear Usuario VLESS TCP                         ${CYAN}│${NC}\n"
printf "${CYAN}│${NC} ${WHITE}[02]${NC} Crear Usuario VLESS WS                          ${CYAN}│${NC}\n"
printf "${CYAN}│${NC} ${WHITE}[03]${NC} Crear Usuario VMESS WS                          ${CYAN}│${NC}\n"
printf "${CYAN}│${NC} ${WHITE}[04]${NC} Crear Usuario TROJAN WS                         ${CYAN}│${NC}\n"
printf "${CYAN}│${NC} ${WHITE}[05]${NC} Renovar Usuario                                 ${CYAN}│${NC}\n"
printf "${CYAN}│${NC} ${WHITE}[06]${NC} Eliminar Usuario                                ${CYAN}│${NC}\n"
printf "${CYAN}│${NC} ${WHITE}[07]${NC} Lista de Usuarios                               ${CYAN}│${NC}\n"
printf "${CYAN}│${NC} ${WHITE}[08]${NC} Usuarios Online                                 ${CYAN}│${NC}\n"
echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${NC}"

echo

echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${NC}"
printf "${CYAN}│${NC} ${RED}[00]${NC} Regresar                                          ${CYAN}│${NC}\n"
echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${NC}"

echo
read -p "Seleccione una opción: " opt

case $opt in

1|01)
    echo
    echo -e "${GREEN}Función en desarrollo: Crear Usuario VLESS TCP${NC}"
    read -p "ENTER para continuar..."
    ;;

2|02)
    echo
    echo -e "${GREEN}Función en desarrollo: Crear Usuario VLESS WS${NC}"
    read -p "ENTER para continuar..."
    ;;

3|03)
    echo
    echo -e "${GREEN}Función en desarrollo: Crear Usuario VMESS WS${NC}"
    read -p "ENTER para continuar..."
    ;;

4|04)
    echo
    echo -e "${GREEN}Función en desarrollo: Crear Usuario TROJAN WS${NC}"
    read -p "ENTER para continuar..."
    ;;

5|05)
    echo
    echo -e "${GREEN}Función en desarrollo: Renovar Usuario${NC}"
    read -p "ENTER para continuar..."
    ;;

6|06)
    echo
    echo -e "${GREEN}Función en desarrollo: Eliminar Usuario${NC}"
    read -p "ENTER para continuar..."
    ;;

7|07)
    echo
    echo -e "${GREEN}Función en desarrollo: Lista de Usuarios${NC}"
    read -p "ENTER para continuar..."
    ;;

8|08)
    echo
    echo -e "${GREEN}Función en desarrollo: Usuarios Online${NC}"
    read -p "ENTER para continuar..."
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
