#!/bin/bash

GREEN='\033[1;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

show_config() {
    clear
    echo -e "${GREEN}══════════════════════════════════════${NC}"
    echo -e "      CONFIGURACIÓN DEL SISTEMA"
    echo -e "${GREEN}══════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}Hostname:${NC} $(hostname)"
    echo -e "${YELLOW}IP Pública:${NC} $(curl -s https://api.ipify.org)"
    echo -e "${YELLOW}SO:${NC} $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
    echo -e "${YELLOW}Kernel:${NC} $(uname -r)"
    echo -e "${YELLOW}CPU:${NC} $(lscpu | grep 'CPU(s)' | head -1 | awk '{print $2}')"
    echo -e "${YELLOW}RAM Total:${NC} $(free -h | grep Mem | awk '{print $2}')"
    echo ""
    read -p "ENTER..."
}

while true; do
    clear
    echo "════════════════════════════"
    echo -e "  ${GREEN}CONFIGURACIÓN${NC}"
    echo "════════════════════════════"
    echo "  [1] Ver Info Sistema"
    echo "  [0] Salir"
    echo "════════════════════════════"
    read -p "Opción: " opt
    
    case $opt in
        1) show_config ;;
        0) break ;;
        *) echo -e "${RED}Inválida${NC}"; sleep 1 ;;
    esac
done
