#!/bin/bash

GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="/usr/local/oxgi"

update_script() {
    clear
    echo -e "${GREEN}══════════════════════════════════════${NC}"
    echo -e "      ACTUALIZANDO OXGI-VPS-SCRIPT"
    echo -e "${GREEN}══════════════════════════════════════${NC}"
    
    if [[ ! -d $SCRIPT_DIR ]]; then
        echo -e "${RED}[!] Directorio no encontrado${NC}"
        read -p "ENTER..."
        return 1
    fi
    
    cd $SCRIPT_DIR
    git pull origin main
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}[OK] Script actualizado${NC}"
        echo -e "${YELLOW}Reinicie el script para aplicar cambios${NC}"
    else
        echo -e "${RED}[!] Error al actualizar${NC}"
    fi
    
    read -p "ENTER..."
}

check_version() {
    if [[ -f $SCRIPT_DIR/version.conf ]]; then
        cat $SCRIPT_DIR/version.conf
    else
        echo "Versión: desconocida"
    fi
    read -p "ENTER..."
}

while true; do
    clear
    echo "════════════════════════════"
    echo -e "  ${GREEN}ACTUALIZADOR${NC}"
    echo "════════════════════════════"
    echo "  [1] Actualizar Script"
    echo "  [2] Ver Versión"
    echo "  [0] Salir"
    echo "════════════════════════════"
    read -p "Opción: " opt
    
    case $opt in
        1) update_script ;;
        2) check_version ;;
        0) break ;;
        *) echo -e "${RED}Inválida${NC}"; sleep 1 ;;
    esac
done
