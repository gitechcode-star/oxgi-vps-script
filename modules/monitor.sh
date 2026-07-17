#!/bin/bash

GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
NC='\033[0m'

show_monitor() {
    while true; do
        clear
        echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
        echo -e "        ${GREEN}MONITOR DEL SISTEMA${NC}"
        echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
        echo ""
        
        # CPU
        CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
        echo -e "${YELLOW}► CPU:${NC} ${GREEN}${CPU}%${NC}"
        
        # RAM
        MEM=$(free | grep Mem | awk '{printf("%.2f", $3/$2 * 100.0)}')
        echo -e "${YELLOW}► RAM:${NC} ${GREEN}${MEM}%${NC}"
        
        # Disco
        DISK=$(df -h / | awk 'NR==2 {print $5}')
        echo -e "${YELLOW}► DISCO:${NC} ${GREEN}${DISK}${NC}"
        
        # Uptime
        UPTIME=$(uptime -p 2>/dev/null || uptime | awk -F',' '{print $1}' | awk '{print $3,$4}')
        echo -e "${YELLOW}► UPTIME:${NC} ${GREEN}${UPTIME}${NC}"
        
        echo ""
        echo -e "${YELLOW}► CONEXIONES ACTIVAS:${NC}"
        SSH_CONN=$(ss -tulpn | grep ':22' | wc -l)
        HTTP_CONN=$(ss -tulpn | grep ':80' | wc -l)
        echo -e "  • SSH (22)  : ${GREEN}${SSH_CONN}${NC}"
        echo -e "  • HTTP (80) : ${GREEN}${HTTP_CONN}${NC}"
        
        echo ""
        echo -e "${YELLOW}► SERVICIOS:${NC}"
        
        # Verificar servicios
        for svc in nginx xray dropbear ssh badvpn; do
            if systemctl is-active $svc > /dev/null 2>&1; then
                echo -e "  ${GREEN}✓${NC} $svc"
            else
                echo -e "  ${RED}✗${NC} $svc"
            fi
        done
        
        echo ""
        echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
        echo -e "  Presiona ${RED}Ctrl+C${NC} para salir"
        echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
        sleep 3
    done
}

show_monitor
