#!/bin/bash
show_header() {
    CONFIG="/etc/oxgi/config.conf"
    VERSION_FILE="/etc/oxgi/version.conf"
    [ -f "$CONFIG" ] && source "$CONFIG"
    [ -f "$VERSION_FILE" ] && source "$VERSION_FILE"
    clear
    echo "══════════════════════════════════════════════════════════════"
    echo " $APP_NAME - Versión : $VERSION - ($AUTHOR)"
    echo "══════════════════════════════════════════════════════════════"
    echo
}
