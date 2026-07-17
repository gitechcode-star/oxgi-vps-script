#!/bin/bash

if [[ $EUID -ne 0 ]]; then
    echo -e "\e[31m[ERROR] Este script debe ejecutarse como root\e[0m"
    exit 1
fi

GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
NC='\033[0m'
BOLD='\033[1m'

DB_FILE="/etc/oxgi/ssh_users.db"
mkdir -p /etc/oxgi

get_ip() {
    curl -s https://api.ipify.org 2>/dev/null || echo "127.0.0.1"
}

get_domain() {
    if [[ -f /etc/oxgi/domain.conf ]]; then
        cat /etc/oxgi/domain.conf
    else
        echo "$(get_ip)"
    fi
}

calculate_expiry() {
    local type=$1
    local amount=$2
    case $type in
        1) date -d "+${amount} months" '+%Y-%m-%d %H:%M:%S' 2>/dev/null ;;
        2) date -d "+${amount} days" '+%Y-%m-%d %H:%M:%S' 2>/dev/null ;;
        3) date -d "+${amount} hours" '+%Y-%m-%d %H:%M:%S' 2>/dev/null ;;
        4) date -d "+${amount} minutes" '+%Y-%m-%d %H:%M:%S' 2>/dev/null ;;
    esac
}

create_user() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "        ${GREEN}${BOLD}CREAR USUARIO SSH${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo ""
    
    read -p "$(echo -e ${YELLOW}Nombre de usuario:${NC} ")" USERNAME
    [[ -z "$USERNAME" ]] && { echo -e "${RED}[!] Datos incompletos.${NC}"; read -p "ENTER..."; return 1; }
    id "$USERNAME" &>/dev/null && { echo -e "${RED}[!] El usuario ya existe.${NC}"; read -p "ENTER..."; return 1; }
    
    read -sp "$(echo -e ${YELLOW}Contraseña:${NC} ")" PASSWORD
    echo ""
    [[ -z "$PASSWORD" ]] && { echo -e "${RED}[!] Datos incompletos.${NC}"; read -p "ENTER..."; return 1; }
    
    echo ""
    read -p "$(echo -e ${YELLOW}Dispositivos permitidos [por defecto 1]:${NC} ")" DEVICES
    DEVICES=${DEVICES:-1}
    [[ ! "$DEVICES" =~ ^[0-9]+$ ]] && DEVICES=1
    
    echo ""
    echo -e "${YELLOW}Elija el tipo de tiempo:${NC}"
    echo -e "  ${GREEN}[1]${NC} Meses (ms)"
    echo -e "  ${GREEN}[2]${NC} Días (ds)"
    echo -e "  ${GREEN}[3]${NC} Horas (hr)"
    echo -e "  ${GREEN}[4]${NC} Minutos (mt)"
    echo ""
    read -p "Opción [1-4]: " TIME_TYPE
    [[ ! "$TIME_TYPE" =~ ^[1-4]$ ]] && { echo -e "${RED}[!] Opción inválida.${NC}"; read -p "ENTER..."; return 1; }
    
    echo ""
    read -p "$(echo -e ${YELLOW}¿Cuánto tiempo?:${NC} ")" TIME_AMOUNT
    [[ ! "$TIME_AMOUNT" =~ ^[0-9]+$ ]] && { echo -e "${RED}[!] Cantidad inválida.${NC}"; read -p "ENTER..."; return 1; }
    
    EXPIRY_DATE=$(calculate_expiry $TIME_TYPE $TIME_AMOUNT)
    EXPIRY_TS=$(date -d "$EXPIRY_DATE" +%s 2>/dev/null)
    AUTO_DELETE_TS=$((EXPIRY_TS + 172800))
    
    useradd -M -s /bin/false "$USERNAME" 2>/dev/null
    echo "$USERNAME:$PASSWORD" | chpasswd 2>/dev/null
    
    CREATED_DATE=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${USERNAME}|${PASSWORD}|${DEVICES}|${CREATED_DATE}|${EXPIRY_DATE}|${AUTO_DELETE_TS}" >> "$DB_FILE"
    
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "        ${GREEN}${BOLD}✓ USUARIO CREADO EXITOSAMENTE${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW} SERVIDOR:${NC}"
    echo -e "  • Dominio: ${WHITE}$(get_domain)${NC}"
    echo -e "  • IP: ${WHITE}$(get_ip)${NC}"
    echo ""
    echo -e "${CYAN}──────────────────────────────────────────────────${NC}"
    echo -e "${YELLOW}👤 DATOS DEL USUARIO:${NC}"
    echo -e "  • Usuario: ${GREEN}${BOLD}${USERNAME}${NC}"
    echo -e "  • Contraseña: ${GREEN}${BOLD}${PASSWORD}${NC}"
    echo -e "  • Dispositivos: ${GREEN}${BOLD}${DEVICES}${NC}"
    echo -e "  • Expiración: ${RED}${BOLD}${EXPIRY_DATE}${NC}"
    echo -e "${CYAN}──────────────────────────────────────────────────${NC}"
    echo ""
    read -p "Presiona ENTER para continuar..."
}

delete_user() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "        ${RED}${BOLD}ELIMINAR USUARIO SSH${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo ""
    read -p "$(echo -e ${YELLOW}Usuario a eliminar:${NC} ")" USERNAME
    [[ -z "$USERNAME" ]] && { echo -e "${RED}[!] Nombre requerido.${NC}"; read -p "ENTER..."; return 1; }
    
    userdel -r "$USERNAME" 2>/dev/null
    [[ -f "$DB_FILE" ]] && { grep -v "^${USERNAME}|" "$DB_FILE" > "${DB_FILE}.tmp"; mv "${DB_FILE}.tmp" "$DB_FILE"; }
    
    echo -e "${GREEN}[OK] Usuario eliminado.${NC}"
    read -p "ENTER..."
}

list_users() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "        ${GREEN}${BOLD}USUARIOS SSH${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo ""
    [[ ! -f "$DB_FILE" ]] && { echo -e "${YELLOW}Sin usuarios.${NC}"; read -p "ENTER..."; return 0; }
    
    printf "${YELLOW}%-15s %-10s %-10s %-20s${NC}\n" "Usuario" "Dispositivos" "Estado" "Expiración"
    echo -e "${CYAN}────────────────────────────────────────────────────────${NC}"
    
    while IFS='|' read -r user pass devices created expiry auto_ts; do
        [[ -z "$user" ]] && continue
        current_ts=$(date +%s)
        if [[ "$current_ts" -gt "$auto_ts" ]]; then
            status="${RED}Eliminado${NC}"
        elif [[ "$current_ts" -gt "$(date -d "$expiry" +%s 2>/dev/null)" ]]; then
            status="${YELLOW}Expirado${NC}"
        else
            status="${GREEN}Activo${NC}"
        fi
        printf "${WHITE}%-15s${NC} %-10s ${status} %-20s\n" "$user" "$devices" "$expiry"
    done < "$DB_FILE"
    
    echo ""
    read -p "ENTER..."
}

while true; do
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "        ${GREEN}${BOLD}SSH MANAGER${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${GREEN}[1]${NC} Crear Usuario"
    echo -e "  ${GREEN}[2]${NC} Eliminar Usuario"
    echo -e "  ${GREEN}[3]${NC} Ver Usuarios"
    echo ""
    echo -e "  ${RED}[0]${NC} Regresar"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo ""
    read -p "Opción [0-3]: " opt

    case $opt in
        1) create_user ;;
        2) delete_user ;;
        3) list_users ;;
        0) break ;;
        *) echo -e "${RED}Opción inválida${NC}"; sleep 1 ;;
    esac
done
