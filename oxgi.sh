#!/bin/bash

# Verificar root
if [[ $EUID -ne 0 ]]; then
    echo -e "\e[31m[ERROR] Este script debe ejecutarse como root.\e[0m"
    exit 1
fi

# Cargar configuración de versión
VERSION_FILE="/usr/local/oxgi/version.conf"
if [[ -f "$VERSION_FILE" ]]; then
    source "$VERSION_FILE"
else
    SCRIPT_NAME="OXGI VPS Script"
    SCRIPT_VERSION="1.0.0"
    DEVELOPER="gitechcode-star"
fi

# Cargar colores (con fallback)
source /usr/local/oxgi/modules/color.sh 2>/dev/null || {
    GREEN='\033[1;32m'; RED='\033[1;31m'; YELLOW='\033[1;33m'; CYAN='\033[1;36m'; NC='\033[0m'; BOLD='\033[1m'
}

# Cargar header (con fallback)
source /usr/local/oxgi/modules/header.sh 2>/dev/null || {
    show_header() {
        clear
        echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║                                                  ║${NC}"
        echo -e "${CYAN}║      ${GREEN}${BOLD}${SCRIPT_NAME}${NC}${CYAN}                      ║${NC}"
        echo -e "${CYAN}║      ${YELLOW}Versión: ${SCRIPT_VERSION} | Dev: ${DEVELOPER}${NC}${CYAN}           ║${NC}"
        echo -e "${CYAN}║                                                  ║${NC}"
        echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
        echo ""
    }
}

MODULES_DIR="/usr/local/oxgi/modules"

while true; do
    show_header
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "  ${GREEN}[1]${NC} Gestión SSH (Usuarios y Conexiones)"
    echo -e "  ${GREEN}[2]${NC} WebSocket Manager (Nginx + Websockify)"
    echo -e "  ${GREEN}[3]${NC} V2Ray / Xray Manager"
    echo -e "  ${GREEN}[4]${NC} BadVPN (UDP Gateway)"
    echo -e "  ${GREEN}[5]${NC} Dropbear Manager"
    echo -e "  ${GREEN}[6]${NC} SSL / Certificados (Let's Encrypt)"
    echo -e "  ${GREEN}[7]${NC} Firewall (UFW)"
    echo -e "  ${GREEN}[8]${NC} Monitor del Sistema"
    echo -e "  ${GREEN}[9]${NC} Configuración y Dominios"
    echo -e "  ${GREEN}[10]${NC} Actualizar Script"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "  ${RED}[0]${NC} Salir"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo ""
    read -p "Seleccione una opción [0-10]: " opt

    case $opt in
        1) bash "$MODULES_DIR/ssh.sh" ;;
        2) bash "$MODULES_DIR/websocket.sh" ;;
        3) bash "$MODULES_DIR/v2ray.sh" ;;
        4) bash "$MODULES_DIR/badvpn.sh" ;;
        5) bash "$MODULES_DIR/dropbear.sh" ;;
        6) bash "$MODULES_DIR/ssl.sh" ;;
        7) bash "$MODULES_DIR/firewall.sh" ;;
        8) bash "$MODULES_DIR/monitor.sh" ;;
        9) bash "$MODULES_DIR/configuracion.sh" ;;
        10) bash "$MODULES_DIR/updater.sh" ;;
        0) clear; echo -e "${GREEN}¡Gracias por usar ${SCRIPT_NAME} v${SCRIPT_VERSION}!${NC}\n"; exit 0 ;;
        *) echo -e "${RED}Opción inválida.${NC}"; sleep 1 ;;
    esac
done
