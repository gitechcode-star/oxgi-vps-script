#!/bin/bash

show_header() {

CONFIG="/etc/oxgi/config.conf"
VERSION_FILE="/etc/oxgi/version.conf"

[ -f "$CONFIG" ] && source "$CONFIG"
[ -f "$VERSION_FILE" ] && source "$VERSION_FILE"

CYAN="\e[1;36m"
WHITE="\e[1;37m"
NC="\e[0m"

clear

echo -e "${CYAN}┌────────────────────────────────────────────────────┐${NC}"
printf "${CYAN}│${NC} %-50s ${CYAN}│${NC}\n" \
"${WHITE}${APP_NAME} - Versión ${VERSION} - ${AUTHOR}${NC}"
echo -e "${CYAN}└────────────────────────────────────────────────────┘${NC}"
echo
}
