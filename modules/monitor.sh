#!/bin/bash
source /etc/oxgi/config.conf
source /usr/local/oxgi/modules/color.sh

while true; do
    clear
    echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│          ${BOLD}SYSTEM MONITOR${NC}"
    echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${NC}"
    echo
    echo -e "${YELLOW}RAM Usage:${NC}"
    free -h
    echo
    echo -e "${YELLOW}Disk Usage:${NC}"
    df -h
    echo
    echo -e "${YELLOW}CPU Info:${NC}"
    lscpu | grep "CPU(s)"
    echo
    echo -e "${YELLOW}Uptime:${NC}"
    uptime -p
    echo
    echo -e "${YELLOW}Active Users:${NC}"
    who | wc -l
    echo
    echo -e "${RED}[0]${NC} Regresar"
    read -p "Opción: " opt
    [[ "$opt" == "0" ]] && break
done
