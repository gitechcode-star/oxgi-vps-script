#!/bin/bash
source /etc/oxgi/config.conf
source /usr/local/oxgi/modules/color.sh
source /usr/local/oxgi/modules/header.sh

while true; do
    clear
    show_header
    echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│          ${BOLD}SSH MANAGER${NC}"
    echo -e "${CYAN}└────────────────────────────────────────────────────────────${NC}"
    echo
    echo -e "${CYAN}[01]${NC} Crear Cuenta SSH"
    echo -e "${CYAN}[02]${NC} Eliminar Cuenta SSH"
    echo -e "${CYAN}[03]${NC} Ver Usuarios Activos"
    echo -e "${CYAN}[04]${NC} Extender Cuenta"
    echo -e "${CYAN}[05]${NC} Check Usuario"
    echo
    echo -e "${RED}[00]${NC} Regresar"
    echo
    read -p "Seleccione: " opt
    case $opt in
        1) bash /usr/local/oxgi/modules/add-ssh.sh ;;
        2) bash /usr/local/oxgi/modules/del-ssh.sh ;;
        3) bash /usr/local/oxgi/modules/cek-ssh.sh ;;
        4) bash /usr/local/oxgi/modules/extend-ssh.sh ;;
        5) bash /usr/local/oxgi/modules/check-user.sh ;;
        0) break ;;
        *) echo -e "${RED}Opción inválida${NC}"; sleep 1 ;;
    esac
done
