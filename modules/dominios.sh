#!/bin/bash

GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

get_ip() {
    curl -s https://api.ipify.org
}

check_domain() {
    clear
    echo -e "${GREEN}══════════════════════════════════════${NC}"
    echo -e "      VERIFICAR DOMINIO"
    echo -e "${GREEN}══════════════════════════════════════${NC}"
    echo ""
    read -p "Dominio: " DOMAIN
    
    if [[ -z "$DOMAIN" ]]; then
        echo -e "${RED}[!] Dominio requerido${NC}"
        read -p "ENTER..."
        return 1
    fi
    
    DOMAIN_IP=$(dig +short $DOMAIN | head -n1)
    SERVER_IP=$(get_ip)
    
    echo ""
    echo -e "${YELLOW}IP del dominio:${NC} $DOMAIN_IP"
    echo -e "${YELLOW}IP del servidor:${NC} $SERVER_IP"
    
    if [[ "$DOMAIN_IP" == "$SERVER_IP" ]]; then
        echo -e "${GREEN}[OK] El dominio apunta correctamente${NC}"
    else
        echo -e "${RED}[!] El dominio NO apunta a este servidor${NC}"
    fi
    
    read -p "ENTER..."
}

while true; do
    clear
    echo "════════════════════════════"
    echo -e "  ${GREEN}DOMINIOS${NC}"
    echo "════════════════════════════"
    echo "  [1] Verificar Dominio"
    echo "  [0] Salir"
    echo "════════════════════════════"
    read -p "Opción: " opt
    
    case $opt in
        1) check_domain ;;
        0) break ;;
        *) echo -e "${RED}Inválida${NC}"; sleep 1 ;;
    esac
done
