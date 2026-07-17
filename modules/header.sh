#!/bin/bash

GREEN='\033[1;32m'
CYAN='\033[1;36m'
NC='\033[0m'

show_header() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                                  ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}      ${GREEN}OXGI VPS SCRIPT${NC}               ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}      ${GREEN}Panel de Control${NC}                ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}                                  ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════╝${NC}"
    echo ""
}

# Ejemplo de uso: source header.sh && show_header
