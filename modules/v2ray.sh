#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
DOMAIN=$(cat /etc/oxgi/domain.conf)
UUID=$(cat /etc/oxgi/xray_uuid)
DB="/etc/oxgi/v2ray.db"
mkdir -p /etc/oxgi && touch "$DB"

add_vmess() {
    clear; echo -e "${CYAN}VMESS${NC}\n"
    read -p "Nombre: " name; [[ -z "$name" ]] && return
    read -p "Días: " days; [[ ! "$days" =~ ^[0-9]+$ ]] && return
    exp=$(date -d "+$days days" +"%Y-%m-%d")
    echo "${name}:${UUID}:vmess:${exp}" >> "$DB"
    echo -e "\n${GREEN}$name${NC} - Exp: $exp"
    echo "vmess://$(echo '{"v":"2","ps":"'$name'","add":"'$DOMAIN'","port":"443","id":"'$UUID'","net":"ws","path":"/vmess","tls":"tls"}' | base64 -w0)"
    read -p "ENTER"
}

add_vless() {
    clear; echo -e "${CYAN}VLESS${NC}\n"
    read -p "Nombre: " name; [[ -z "$name" ]] && return
    read -p "Días: " days; [[ ! "$days" =~ ^[0-9]+$ ]] && return
    exp=$(date -d "+$days days" +"%Y-%m-%d")
    echo "${name}:${UUID}:vless:${exp}" >> "$DB"
    echo -e "\n${GREEN}$name${NC} - Exp: $exp"
    echo "vless://${UUID}@${DOMAIN}:443?encryption=none&security=tls&type=ws&path=/vless#${name}"
    read -p "ENTER"
}

add_trojan() {
    clear; echo -e "${CYAN}TROJAN${NC}\n"
    read -p "Nombre: " name; [[ -z "$name" ]] && return
    read -p "Días: " days; [[ ! "$days" =~ ^[0-9]+$ ]] && return
    exp=$(date -d "+$days days" +"%Y-%m-%d")
    echo "${name}:${UUID}:trojan:${exp}" >> "$DB"
    echo -e "\n${GREEN}$name${NC} - Exp: $exp"
    echo "trojan://${UUID}@${DOMAIN}:443?security=tls&type=ws&path=/trojan#${name}"
    read -p "ENTER"
}

lista() {
    clear; echo -e "${CYAN}V2RAY USERS${NC}\n"
    [[ ! -s "$DB" ]] && { echo "Sin usuarios"; read -p "ENTER"; return; }
    printf "%-15s %-10s %-20s\n" "USER" "TYPE" "EXPIRA"
    while IFS=':' read -r n u t e; do printf "%-15s %-10s %-20s\n" "$n" "$t" "$e"; done < "$DB"
    read -p "ENTER"
}

while true; do
    clear; echo -e "${CYAN}V2RAY MANAGER${NC}\n"
    echo "[1] VMESS [2] VLESS [3] TROJAN [4] Lista [0] Salir"
    read -p "Opción: " o
    case $o in 1) add_vmess;; 2) add_vless;; 3) add_trojan;; 4) lista;; 0) exit 0;; esac
done
