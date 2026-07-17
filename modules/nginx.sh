#!/bin/bash

if [[ $EUID -ne 0 ]]; then
   echo -e "\e[31m[ERROR] Requiere root.${NC}\e[0m"
   exit 1
fi

GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

install_nginx() {
    clear
    echo -e "${GREEN}══════════════════════════════════════${NC}"
    echo -e "      INSTALANDO NGINX"
    echo -e "${GREEN}══════════════════════════════════════${NC}"
    
    apt update -y > /dev/null 2>&1
    apt install -y nginx > /dev/null 2>&1
    
    systemctl enable nginx > /dev/null 2>&1
    systemctl start nginx
    
    if command -v ufw > /dev/null; then
        ufw allow 'Nginx Full' > /dev/null 2>&1
    fi
    
    echo -e "${GREEN}[OK] Nginx instalado y activo.${NC}"
    read -p "Presiona ENTER..."
}

restart_nginx() {
    systemctl restart nginx
    echo -e "${GREEN}[OK] Nginx reiniciado.${NC}"
    read -p "Presiona ENTER..."
}

status_nginx() {
    clear
    echo -e "${GREEN}► Estado:$(systemctl is-active nginx > /dev/null && echo -e " ${GREEN}[ACTIVO]${NC}" || echo -e " ${RED}[INACTIVO]${NC}")"
    echo ""
    ss -tulpn | grep ':80\|:443'
    read -p "Presiona ENTER..."
}

test_config() {
    echo -e "${YELLOW}[*] Probando configuración...${NC}"
    nginx -t
    read -p "Presiona ENTER..."
}

while true; do
    clear
    echo "══════════════════════════════════════"
    echo -e "        ${GREEN}NGINX MANAGER${NC}"
    echo "══════════════════════════════════════"
    echo ""
    echo -e "  [1] ${GREEN}Instalar Nginx${NC}"
    echo -e "  [2] ${YELLOW}Reiniciar${NC}"
    echo -e "  [3] ${YELLOW}Ver Estado${NC}"
    echo -e "  [4] ${YELLOW}Probar Config${NC}"
    echo ""
    echo -e "  [0] ${NC}Regresar"
    echo "══════════════════════════════════════"
    read -p "Opción [0-4]: " opt

    case $opt in
        1) install_nginx ;;
        2) restart_nginx ;;
        3) status_nginx ;;
        4) test_config ;;
        0) break ;;
        *) echo -e "${RED}Inválida${NC}"; sleep 1 ;;
    esac
done
