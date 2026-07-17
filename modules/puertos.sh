#!/bin/bash

GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

show_ports() {
    clear
    echo -e "${GREEN}══════════════════════════════════════${NC}"
    echo -e "      PUERTOS ABIERTOS"
    echo -e "${GREEN}══════════════════════════════════════${NC}"
    echo ""
    ss -tulpn
    echo ""
    read -p "ENTER..."
}

check_port() {
    read -p "Puerto: " PORT
    ss -tulpn | grep ":$PORT" && echo -e "${GREEN}Abierto${NC}" || echo -e "${RED}Cerrado${NC}"
    read -p "ENTER..."
}

while true; do
    clear
    echo "════════════════════════════"
    echo -e "  ${GREEN}PUERTOS${NC}"
    echo "════════════════════════════"
    echo "  [1] Ver Todos"
    echo "  [2] Consultar Puerto"
    echo "  [0] Salir"
    echo "════════════════════════════"
    read -p "Opción: " opt
    
    case $opt in
        1) show_ports ;;
        2) check_port ;;
        0) break ;;
        *) echo -e "${RED}Inválida${NC}"; sleep 1 ;;
    esac
done
