#!/bin/bash

source /usr/local/oxgi/modules/color.sh
source /usr/local/oxgi/modules/header.sh

while true
do

show_header

echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│${NC} ${WHITE}XRAY / V2RAY MANAGER${NC}"
echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${NC}"

echo

echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│${NC} ${GREEN}[01]${NC} Crear Usuario VLESS TCP"
echo -e "${CYAN}│${NC} ${GREEN}[02]${NC} Crear Usuario VLESS WS"
echo -e "${CYAN}│${NC} ${GREEN}[03]${NC} Crear Usuario VMESS WS"
echo -e "${CYAN}│${NC} ${GREEN}[04]${NC} Crear Usuario TROJAN WS"
echo -e "${CYAN}│${NC} ${GREEN}[05]${NC} Renovar Usuario"
echo -e "${CYAN}│${NC} ${GREEN}[06]${NC} Eliminar Usuario"
echo -e "${CYAN}│${NC} ${GREEN}[07]${NC} Lista de Usuarios"
echo -e "${CYAN}│${NC} ${GREEN}[08]${NC} Usuarios Online"
echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${NC}"

echo

echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│${NC} ${RED}[00]${NC} Regresar"
echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${NC}"

echo
read -p "Seleccione una opción: " opt

case $opt in

1|01)
    clear
    echo
    echo -e "${GREEN}Función en desarrollo:${NC} Crear Usuario VLESS TCP"
    echo
    read -p "ENTER para continuar..."
    ;;

2|02)
    clear
    echo
    echo -e "${GREEN}Función en desarrollo:${NC} Crear Usuario VLESS WS"
    echo
    read -p "ENTER para continuar..."
    ;;

3|03)
    clear
    echo
    echo -e "${GREEN}Función en desarrollo:${NC} Crear Usuario VMESS WS"
    echo
    read -p "ENTER para continuar..."
    ;;

4|04)
    clear
    echo
    echo -e "${GREEN}Función en desarrollo:${NC} Crear Usuario TROJAN WS"
    echo
    read -p "ENTER para continuar..."
    ;;

5|05)
    clear
    echo
    echo -e "${GREEN}Función en desarrollo:${NC} Renovar Usuario"
    echo
    read -p "ENTER para continuar..."
    ;;

6|06)
    clear
    echo
    echo -e "${GREEN}Función en desarrollo:${NC} Eliminar Usuario"
    echo
    read -p "ENTER para continuar..."
    ;;

7|07)
    clear
    echo
    echo -e "${GREEN}Función en desarrollo:${NC} Lista de Usuarios"
    echo
    read -p "ENTER para continuar..."
    ;;

8|08)
    clear
    echo
    echo -e "${GREEN}Función en desarrollo:${NC} Usuarios Online"
    echo
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
