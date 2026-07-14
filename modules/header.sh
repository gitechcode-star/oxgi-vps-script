#!/bin/bash

show_header() {

CONFIG="/etc/oxgi/config.conf"
VERSION_FILE="/etc/oxgi/version.conf"

[ -f "$CONFIG" ] && source "$CONFIG"
[ -f "$VERSION_FILE" ] && source "$VERSION_FILE"

BLUE='\033[1;36m'
WHITE='\033[1;37m'
NC='\033[0m'

clear

echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${WHITE}      ${APP_NAME} - Versión ${VERSION} - ${AUTHOR}      ${BLUE}║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"
echo
}
