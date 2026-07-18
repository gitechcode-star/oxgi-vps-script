#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
DB="/etc/oxgi/ssh_users.db"
mkdir -p /etc/oxgi && touch "$DB"

crear() {
    clear; echo -e "${CYAN}CREAR USUARIO SSH${NC}\n"
    read -p "Usuario: " user
    [[ ! "$user" =~ ^[a-zA-Z0-9_]+$ ]] || [[ ${#user} -lt 3 ]] && { echo -e "${RED}Inválido${NC}"; read -p "ENTER"; return; }
    id "$user" &>/dev/null && { echo -e "${RED}Existe${NC}"; read -p "ENTER"; return; }
    read -p "Password (blank=auto): " pass
    [[ -z "$pass" ]] && pass=$(openssl rand -base64 10 | tr -dc 'a-zA-Z0-9' | head -c8)
    echo -e "\n[1] Minutos [2] Horas [3] Días [4] Meses [5] Años"
    read -p "Unidad: " u
    case $u in 1) m=60;; 2) m=3600;; 3) m=86400;; 4) m=2592000;; 5) m=31536000;; *) echo "Inválido"; return;; esac
    read -p "Cantidad: " c
    [[ ! "$c" =~ ^[0-9]+$ ]] && { echo "Inválido"; return; }
    read -p "Max dispositivos: " dev
    [[ ! "$dev" =~ ^[0-9]+$ ]] && { echo "Inválido"; return; }
    exp=$(date -d "+$((c*m)) seconds" +"%Y-%m-%d %H:%M:%S")
    expd=$(echo "$exp" | cut -d' ' -f1)
    useradd -e "$expd" -s /bin/false -M "$user"
    echo "$user:$pass" | chpasswd
    echo "${user}:$(date +%s):${exp}:${dev}" >> "$DB"
    echo -e "\n${GREEN}Creado:${NC} $user | Pass: $pass | Exp: $exp | Dev: $dev"
    read -p "ENTER"
}

eliminar() {
    clear; echo -e "${CYAN}ELIMINAR USUARIO${NC}\n"
    read -p "Usuario: " user
    id "$user" &>/dev/null || { echo -e "${RED}No existe${NC}"; read -p "ENTER"; return; }
    userdel -r "$user" 2>/dev/null
    sed -i "/^${user}:/d" "$DB"
    echo -e "${GREEN}Eliminado${NC}"; read -p "ENTER"
}

lista() {
    clear; echo -e "${CYAN}USUARIOS${NC}\n"
    [[ ! -s "$DB" ]] && { echo "Sin usuarios"; read -p "ENTER"; return; }
    printf "%-15s %-25s %-5s\n" "USER" "EXPIRA" "DEV"
    while IFS=':' read -r u t e d; do printf "%-15s %-25s %-5s\n" "$u" "$e" "$d"; done < "$DB"
    read -p "ENTER"
}

online() {
    clear; echo -e "${CYAN}ONLINE${NC}\n"
    who | awk '{print $1}' | sort | uniq -c
    read -p "ENTER"
}

while true; do
    clear; echo -e "${CYAN}USER MANAGER${NC}\n"
    echo "[1] Crear [2] Eliminar [3] Lista [4] Online [0] Salir"
    read -p "Opción: " o
    case $o in 1) crear;; 2) eliminar;; 3) lista;; 4) online;; 0) exit 0;; esac
done
