#!/bin/bash
source /etc/oxgi/config.conf
source /usr/local/oxgi/modules/color.sh
source /usr/local/oxgi/modules/header.sh

while true; do
    clear
    show_header
    echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│          ${BOLD}V2RAY / XRAY MANAGER${NC}"
    echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${NC}"
    echo
    echo -e "${CYAN}[01]${NC} Add Vmess"
    echo -e "${CYAN}[02]${NC} Add Vless"
    echo -e "${CYAN}[03]${NC} Add Trojan"
    echo -e "${CYAN}[04]${NC} Add Shadowsocks"
    echo -e "${CYAN}[05]${NC} Ver Cuentas"
    echo -e "${CYAN}[06]${NC} Eliminar Cuenta"
    echo
    echo -e "${RED}[00]${NC} Regresar"
    echo
    read -p "Seleccione: " opt
    case $opt in
        1) bash /usr/local/oxgi/modules/add-vmess.sh ;;
        2) bash /usr/local/oxgi/modules/add-vless.sh ;;
        3) bash /usr/local/oxgi/modules/add-trojan.sh ;;
        4) bash /usr/local/oxgi/modules/add-ss.sh ;;
        5) bash /usr/local/oxgi/modules/cek-v2ray.sh ;;
        6) bash /usr/local/oxgi/modules/del-v2ray.sh ;;
        0) break ;;
        *) echo -e "${RED}Opción inválida${NC}"; sleep 1 ;;
    esac
done
