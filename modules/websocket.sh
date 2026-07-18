#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
while true; do
    clear; echo -e "${GREEN}WEBSOCKET MANAGER${NC}\n"
    echo "[1] Restart [2] Stop [3] Start [4] Status [5] Logs [0] Exit"
    read -p "Option: " o
    case $o in
        1) systemctl restart ws-stunnel; echo "Done"; read -p "ENTER";;
        2) systemctl stop ws-stunnel; echo "Done"; read -p "ENTER";;
        3) systemctl start ws-stunnel; echo "Done"; read -p "ENTER";;
        4) systemctl status ws-stunnel --no-pager; read -p "ENTER";;
        5) journalctl -u ws-stunnel -n 30 --no-pager; read -p "ENTER";;
        0) exit 0;;
    esac
done
