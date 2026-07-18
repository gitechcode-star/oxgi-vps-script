#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
while true; do
    clear; echo -e "${GREEN}NGINX MANAGER${NC}\n"
    echo "[1] Restart [2] Stop [3] Start [4] Status [5] Test [0] Exit"
    read -p "Option: " o
    case $o in
        1) systemctl restart nginx; echo "Done"; read -p "ENTER";;
        2) systemctl stop nginx; echo "Done"; read -p "ENTER";;
        3) systemctl start nginx; echo "Done"; read -p "ENTER";;
        4) systemctl status nginx --no-pager; read -p "ENTER";;
        5) nginx -t; read -p "ENTER";;
        0) exit 0;;
    esac
done
