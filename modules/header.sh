#!/bin/bash

# Cargar configuración de versión
VERSION_FILE="/usr/local/oxgi/version.conf"
if [[ -f "$VERSION_FILE" ]]; then
    source "$VERSION_FILE"
else
    # Valores por defecto si el archivo no existe aún
    SCRIPT_NAME="OXGI VPS Script"
    SCRIPT_VERSION="1.0.0"
    DEVELOPER="gitechcode-star"
fi

# Colores
GREEN='\033[1;32m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
NC='\033[0m'
BOLD='\033[1m'

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
