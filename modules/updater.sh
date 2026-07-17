#!/bin/bash

if [[ $EUID -ne 0 ]]; then
   echo -e "\e[31m[ERROR] Requiere root.${NC}\e[0m"
   exit 1
fi

GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
NC='\033[0m'

VERSION_FILE="/usr/local/oxgi/version.conf"
if [[ -f "$VERSION_FILE" ]]; then
    source "$VERSION_FILE"
else
    SCRIPT_NAME="OXGI VPS Script"
    SCRIPT_VERSION="1.0.0"
    REPO_URL="https://github.com/gitechcode-star/oxgi-vps-script"
    BRANCH="main"
fi

INSTALL_DIR="/usr/local/oxgi"

update_script() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "      ACTUALIZANDO ${SCRIPT_NAME}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}Versión actual: ${SCRIPT_VERSION}${NC}"
    echo -e "${YELLOW}Repositorio   : ${REPO_URL}${NC}"
    echo ""
    
    if [[ ! -d $INSTALL_DIR ]]; then
        echo -e "${RED}[!] Directorio de instalación no encontrado.${NC}"
        read -p "Presiona ENTER..."
        return 1
    fi
    
    cd $INSTALL_DIR
    echo -e "${YELLOW}[*] Descargando actualizaciones...${NC}"
    git fetch origin $BRANCH > /dev/null 2>&1
    
    LOCAL=$(git rev-parse HEAD)
    REMOTE=$(git rev-parse origin/$BRANCH)
    
    if [[ "$LOCAL" != "$REMOTE" ]]; then
        git pull origin $BRANCH > /dev/null 2>&1
        chmod +x *.sh modules/*.sh 2>/dev/null
        
        # Recargar variables por si la versión cambió
        source "$VERSION_FILE"
        
        echo -e "${GREEN}[OK] Script actualizado a la versión ${SCRIPT_VERSION}${NC}"
        echo -e "${YELLOW}⚠️  Reinicia el menú para aplicar los cambios.${NC}"
    else
        echo -e "${GREEN}[OK] Ya estás en la última versión (${SCRIPT_VERSION}).${NC}"
    fi
    
    read -p "Presiona ENTER..."
}

show_version() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "      INFORMACIÓN DE VERSIÓN"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  • Nombre     : ${GREEN}${SCRIPT_NAME}${NC}"
    echo -e "  • Versión    : ${GREEN}${SCRIPT_VERSION}${NC}"
    echo -e "  • Desarrollador: ${GREEN}${DEVELOPER}${NC}"
    echo -e "  • Repositorio: ${CYAN}${REPO_URL}${NC}"
    echo ""
    read -p "Presiona ENTER..."
}

while true; do
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "        ${GREEN}ACTUALIZADOR${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  [1] ${GREEN}Buscar e Instalar Actualización${NC}"
    echo -e "  [2] ${YELLOW}Ver Información de Versión${NC}"
    echo ""
    echo -e "  [0] ${NC}Regresar"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    read -p "Opción [0-2]: " opt
    
    case $opt in
        1) update_script ;;
        2) show_version ;;
        0) break ;;
        *) echo -e "${RED}Opción inválida.${NC}"; sleep 1 ;;
    esac
done
