#!/bin/bash

GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

update_system() {
    echo -e "${YELLOW}[*] Actualizando sistema...${NC}"
    apt update && apt upgrade -y
    echo -e "${GREEN}[OK] Actualizado${NC}"
    read -p "ENTER..."
}

reboot_server() {
    read -p "¿Reiniciar servidor? (s/n): " confirm
    [[ "$confirm" == "s" || "$confirm" == "S" ]] && reboot
}

clean_system() {
    echo -e "${YELLOW}[*] Limpiando paquetes...${NC}"
    apt autoremove -y && apt autoclean
    echo -e "${GREEN}[OK] Limpieza completada${NC}"
    read -p "ENTER..."
}

while true; do
    clear
    echo "════════════════════════════"
    echo -e "  ${GREEN}SISTEMA${NC}"
    echo "════════════════════════════"
    echo "  [1] Actualizar"
    echo "  [2] Reiniciar"
    echo "  [3] Limpiar"
    echo "  [0] Salir"
    echo "════════════════════════════"
    read -p "Opción: " opt
    
    case $opt in
        1) update_system ;;
        2) reboot_server ;;
        3) clean_system ;;
        0) break ;;
        *) echo -e "${RED}Inválida${NC}"; sleep 1 ;;
    esac
done
