
#!/bin/bash

if [[ $EUID -ne 0 ]]; then
   echo -e "\e[31m[ERROR] Requiere root.${NC}\e[0m"
   exit 1
fi

GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

install_ufw() {
    apt install -y ufw > /dev/null 2>&1
    echo -e "${GREEN}[OK] UFW instalado.${NC}"
}

enable_firewall() {
    install_ufw
    ufw --force enable
    echo -e "${GREEN}[OK] Firewall activado.${NC}"
    read -p "Presiona ENTER..."
}

disable_firewall() {
    ufw --force disable
    echo -e "${YELLOW}[OK] Firewall desactivado.${NC}"
    read -p "Presiona ENTER..."
}

allow_port() {
    read -p "Puerto a abrir: " PORT
    read -p "Protocolo (tcp/udp/any): " PROTO
    PROTO=${PROTO:-tcp}
    ufw allow ${PORT}/${PROTO}
    echo -e "${GREEN}[OK] Puerto ${PORT}/${PROTO} abierto.${NC}"
    read -p "Presiona ENTER..."
}

deny_port() {
    read -p "Puerto a bloquear: " PORT
    ufw deny ${PORT}
    echo -e "${RED}[OK] Puerto ${PORT} bloqueado.${NC}"
    read -p "Presiona ENTER..."
}

status_firewall() {
    clear
    echo -e "${GREEN}══════════════════════════════════════${NC}"
    echo -e "        ESTADO DEL FIREWALL"
    echo -e "${GREEN}══════════════════════════════════════${NC}"
    echo ""
    ufw status verbose
    echo ""
    read -p "Presiona ENTER..."
}

reset_firewall() {
    read -p "¿Resetear firewall? (s/n): " confirm
    if [[ "$confirm" == "s" || "$confirm" == "S" ]]; then
        ufw --force reset
        echo -e "${GREEN}[OK] Firewall reseteado.${NC}"
    fi
    read -p "Presiona ENTER..."
}

while true; do
    clear
    echo "══════════════════════════════════════"
    echo -e "        ${GREEN}FIREWALL MANAGER${NC}"
    echo "══════════════════════════════════════"
    echo ""
    echo -e "  [1] ${GREEN}Activar Firewall${NC}"
    echo -e "  [2] ${RED}Desactivar${NC}"
    echo -e "  [3] ${GREEN}Abrir Puerto${NC}"
    echo -e "  [4] ${RED}Bloquear Puerto${NC}"
    echo -e "  [5] ${YELLOW}Ver Estado${NC}"
    echo -e "  [6] ${RED}Resetear${NC}"
    echo ""
    echo -e "  [0] ${NC}Regresar"
    echo "══════════════════════════════════════"
    read -p "Opción [0-6]: " opt

    case $opt in
        1) enable_firewall ;;
        2) disable_firewall ;;
        3) allow_port ;;
        4) deny_port ;;
        5) status_firewall ;;
        6) reset_firewall ;;
        0) break ;;
        *) echo -e "${RED}Inválida${NC}"; sleep 1 ;;
    esac
done
