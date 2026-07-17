#!/bin/bash

if [[ $EUID -ne 0 ]]; then
   echo -e "\e[31m[ERROR] Este script debe ejecutarse como root.\e[0m"
   exit 1
fi

GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

DROPBEAR_PORT="444"

install_dropbear() {
    clear
    echo -e "${GREEN}══════════════════════════════════════${NC}"
    echo -e "      INSTALANDO DROPBEAR SSH"
    echo -e "${GREEN}══════════════════════════════════════${NC}"
    
    apt update -y > /dev/null 2>&1
    apt install -y dropbear > /dev/null 2>&1
    
    # Configurar Dropbear
    cat > /etc/default/dropbear << EOF
NO_START=0
DROPBEAR_PORT=${DROPBEAR_PORT}
DROPBEAR_EXTRA_ARGS="-w -s -j -k"
DROPBEAR_RSAKEY="/etc/dropbear/dropbear_rsa_host_key"
DROPBEAR_DSSKEY="/etc/dropbear/dropbear_dss_host_key"
EOF
    
    systemctl enable dropbear > /dev/null 2>&1
    systemctl restart dropbear
    
    # Firewall
    if command -v ufw > /dev/null; then
        ufw allow ${DROPBEAR_PORT}/tcp > /dev/null 2>&1
    fi
    
    clear
    echo -e "${GREEN}══════════════════════════════════════${NC}"
    echo -e "      ${GREEN}DROPBEAR INSTALADO${NC}"
    echo -e "${GREEN}══════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}📌 Configuración:${NC}"
    echo -e "  • Puerto : ${GREEN}${DROPBEAR_PORT}${NC}"
    echo -e "  • Estado : Activo"
    echo ""
    read -p "Presiona ENTER para continuar..."
}

restart_service() {
    systemctl restart dropbear
    echo -e "${GREEN}[OK] Dropbear reiniciado.${NC}"
    read -p "Presiona ENTER..."
}

status_service() {
    clear
    echo -e "${GREEN}► Servicio:$(systemctl is-active dropbear > /dev/null && echo -e " ${GREEN}[ACTIVO]${NC}" || echo -e " ${RED}[INACTIVO]${NC}")"
    echo -e "${YELLOW}► Puerto:${NC}"
    ss -tulpn | grep ${DROPBEAR_PORT} || echo "  No en escucha"
    read -p "Presiona ENTER..."
}

uninstall_dropbear() {
    read -p "¿Desinstalar Dropbear? (s/n): " confirm
    if [[ "$confirm" == "s" || "$confirm" == "S" ]]; then
        systemctl stop dropbear > /dev/null 2>&1
        systemctl disable dropbear > /dev/null 2>&1
        apt remove --purge -y dropbear > /dev/null 2>&1
        echo -e "${GREEN}[OK] Desinstalado.${NC}"
    fi
    read -p "Presiona ENTER..."
}

while true; do
    clear
    echo "══════════════════════════════════════"
    echo -e "        ${GREEN}DROPBEAR MANAGER${NC}"
    echo "══════════════════════════════════════"
    echo ""
    echo -e "  [1] ${GREEN}Instalar Dropbear${NC}"
    echo -e "  [2] ${YELLOW}Reiniciar${NC}"
    echo -e "  [3] ${YELLOW}Ver Estado${NC}"
    echo -e "  [4] ${RED}Desinstalar${NC}"
    echo ""
    echo -e "  [0] ${NC}Regresar"
    echo "══════════════════════════════════════"
    read -p "Opción [0-4]: " opt

    case $opt in
        1) install_dropbear ;;
        2) restart_service ;;
        3) status_service ;;
        4) uninstall_dropbear ;;
        0) break ;;
        *) echo -e "${RED}Inválida${NC}"; sleep 1 ;;
    esac
done
