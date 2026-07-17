#!/bin/bash

if [[ $EUID -ne 0 ]]; then
    echo -e "\e[31m[ERROR] Requiere root\e[0m"
    exit 1
fi

VERSION_FILE="/usr/local/oxgi/version.conf"
if [[ -f "$VERSION_FILE" ]]; then
    source "$VERSION_FILE"
else
    SCRIPT_NAME="OXGI VPS Script"
    SCRIPT_VERSION="1.0.0"
    DEVELOPER="gitechcode-star"
fi

GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
NC='\033[0m'
BOLD='\033[1m'

MODULES_DIR="/usr/local/oxgi/modules"

while true; do
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                                                  ║${NC}"
    echo -e "${CYAN}║      ${GREEN}${BOLD}${SCRIPT_NAME}${NC}${CYAN}                      ║${NC}"
    echo -e "${CYAN}║      ${YELLOW}v${SCRIPT_VERSION} | ${DEVELOPER}${NC}${CYAN}                    ║${NC}"
    echo -e "${CYAN}║                                                  ║${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "  ${GREEN}[1]${NC} SSH Manager (Usuarios)"
    echo -e "  ${GREEN}[2]${NC} WebSocket SSH (Puerto 80)"
    echo -e "  ${GREEN}[3]${NC} V2Ray/Xray Core (VLESS)"
    echo -e "  ${GREEN}[4]${NC} BadVPN UDP (Puerto 7300)"
    echo -e "  ${GREEN}[5]${NC} Dropbear (Puerto 444)"
    echo -e "  ${GREEN}[6]${NC} SSL/HTTPS (Certbot)"
    echo -e "  ${GREEN}[7]${NC} Firewall (UFW)"
    echo -e "  ${GREEN}[8]${NC} Monitor del Sistema"
    echo -e "  ${GREEN}[9]${NC} Configuración"
    echo -e "  ${GREEN}[10]${NC} Actualizar Script"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "  ${RED}[0]${NC} Salir"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo ""
    read -p "Opción [0-10]: " opt

    case $opt in
        1) bash "$MODULES_DIR/ssh.sh" 2>/dev/null || echo -e "${RED}Módulo no disponible${NC}"; sleep 2 ;;
        2) bash "$MODULES_DIR/websocket.sh" 2>/dev/null || echo -e "${RED}Módulo no disponible${NC}"; sleep 2 ;;
        3) bash "$MODULES_DIR/v2ray.sh" 2>/dev/null || echo -e "${RED}Módulo no disponible${NC}"; sleep 2 ;;
        4) bash "$MODULES_DIR/badvpn.sh" 2>/dev/null || echo -e "${RED}Módulo no disponible${NC}"; sleep 2 ;;
        5) bash "$MODULES_DIR/dropbear.sh" 2>/dev/null || echo -e "${RED}Módulo no disponible${NC}"; sleep 2 ;;
        6) bash "$MODULES_DIR/ssl.sh" 2>/dev/null || echo -e "${RED}Módulo no disponible${NC}"; sleep 2 ;;
        7) bash "$MODULES_DIR/firewall.sh" 2>/dev/null || echo -e "${RED}Módulo no disponible${NC}"; sleep 2 ;;
        8) bash "$MODULES_DIR/monitor.sh" ;;
        9) bash "$MODULES_DIR/configuracion.sh" 2>/dev/null || echo -e "${RED}Módulo no disponible${NC}"; sleep 2 ;;
        10) bash "$MODULES_DIR/updater.sh" 2>/dev/null || echo -e "${RED}Módulo no disponible${NC}"; sleep 2 ;;
        0) clear; echo -e "${GREEN}¡Gracias!${NC}\n"; exit 0 ;;
        *) echo -e "${RED}Opción inválida${NC}"; sleep 1 ;;
    esac
done
