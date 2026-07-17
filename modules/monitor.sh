
#!/bin/bash

GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

show_monitor() {
    while true; do
        clear
        echo -e "${GREEN}══════════════════════════════════════${NC}"
        echo -e "        MONITOR DEL SISTEMA"
        echo -e "${GREEN}══════════════════════════════════════${NC}"
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
        
        # Conexiones
        echo ""
        echo -e "${YELLOW}► CONEXIONES ACTIVAS:${NC}"
        echo "  SSH: $(ss -tulpn | grep ':22' | wc -l)"
        echo "  HTTP: $(ss -tulpn | grep ':80' | wc -l)"
        
        echo ""
        echo -e "${YELLOW}► SERVICIOS:${NC}"
        for svc in nginx xray dropbear ssh; do
            systemctl is-active $svc > /dev/null 2>&1 && echo -e "  ${GREEN}✓${NC} $svc" || echo -e "  ${RED}✗${NC} $svc"
        done
        
        echo ""
        echo "Presiona Ctrl+C para salir"
        sleep 3
    done
}

show_monitor
