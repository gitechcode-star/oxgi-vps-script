#!/bin/bash

if [[ $EUID -ne 0 ]]; then
   echo -e "\e[31m[ERROR] Requiere root.${NC}\e[0m"
   exit 1
fi

GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

install_certbot() {
    clear
    echo -e "${GREEN}══════════════════════════════════════${NC}"
    echo -e "      INSTALANDO CERTBOT (SSL)"
    echo -e "${GREEN}══════════════════════════════════════${NC}"
    
    apt update -y > /dev/null 2>&1
    apt install -y certbot python3-certbot-nginx > /dev/null 2>&1
    
    echo -e "${GREEN}[OK] Certbot instalado.${NC}"
    read -p "Presiona ENTER..."
}

request_cert() {
    clear
    echo -e "${GREEN}══════════════════════════════════════${NC}"
    echo -e "      SOLICITAR CERTIFICADO SSL"
    echo -e "${GREEN}══════════════════════════════════════${NC}"
    echo ""
    read -p "Ingrese su dominio: " DOMAIN
    
    if [[ -z "$DOMAIN" ]]; then
        echo -e "${RED}[!] Dominio requerido.${NC}"
        read -p "Presiona ENTER..."
        return 1
    fi
    
    echo -e "${YELLOW}[*] Solicitando certificado para: $DOMAIN${NC}"
    certbot certonly --standalone -d $DOMAIN --non-interactive --agree-tos -m admin@$DOMAIN
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}[OK] Certificado obtenido.${NC}"
        echo ""
        echo -e "${YELLOW}📍 Ubicación:${NC}"
        echo -e "  /etc/letsencrypt/live/$DOMAIN/"
    else
        echo -e "${RED}[!] Error al obtener certificado.${NC}"
    fi
    
    read -p "Presiona ENTER..."
}

renew_cert() {
    echo -e "${YELLOW}[*] Renovando certificados...${NC}"
    certbot renew --dry-run
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}[OK] Renovación exitosa.${NC}"
    else
        echo -e "${RED}[!] Error en renovación.${NC}"
    fi
    read -p "Presiona ENTER..."
}

list_certs() {
    clear
    echo -e "${GREEN}══════════════════════════════════════${NC}"
    echo -e "      CERTIFICADOS INSTALADOS"
    echo -e "${GREEN}══════════════════════════════════════${NC}"
    echo ""
    if [[ -d /etc/letsencrypt/live ]]; then
        ls -la /etc/letsencrypt/live/
    else
        echo -e "${RED}No hay certificados.${NC}"
    fi
    echo ""
    read -p "Presiona ENTER..."
}

while true; do
    clear
    echo "══════════════════════════════════════"
    echo -e "        ${GREEN}SSL MANAGER${NC}"
    echo "══════════════════════════════════════"
    echo ""
    echo -e "  [1] ${GREEN}Instalar Certbot${NC}"
    echo -e "  [2] ${YELLOW}Solicitar Certificado${NC}"
    echo -e "  [3] ${YELLOW}Renovar Certificado${NC}"
    echo -e "  [4] ${YELLOW}Ver Certificados${NC}"
    echo ""
    echo -e "  [0] ${NC}Regresar"
    echo "══════════════════════════════════════"
    read -p "Opción [0-4]: " opt

    case $opt in
        1) install_certbot ;;
        2) request_cert ;;
        3) renew_cert ;;
        4) list_certs ;;
        0) break ;;
        *) echo -e "${RED}Inválida${NC}"; sleep 1 ;;
    esac
done
