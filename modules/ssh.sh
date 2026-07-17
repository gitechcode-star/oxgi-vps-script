#!/bin/bash
GREEN='\033[1;32m'; RED='\033[1;31m'; CYAN='\033[1;36m'; YELLOW='\033[1;33m'; NC='\033[0m'
DB="/etc/oxgi/ssh_users.db"
mkdir -p /etc/oxgi

IP=$(curl -s https://api.ipify.org)

create_user() {
clear
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "        ${GREEN}CREAR USUARIO SSH${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo ""

read -p "Usuario: " USER
if [[ -z "$USER" ]]; then
    echo -e "${RED}[!] Datos incompletos${NC}"
    read -p "ENTER..."
    return 1
fi

if id "$USER" &>/dev/null; then
    echo -e "${RED}[!] El usuario ya existe${NC}"
    read -p "ENTER..."
    return 1
fi

read -sp "Contraseña: " PASS
echo ""
if [[ -z "$PASS" ]]; then
    echo -e "${RED}[!] Datos incompletos${NC}"
    read -p "ENTER..."
    return 1
fi

echo ""
read -p "Dispositivos permitidos [1]: " DEV
DEV=${DEV:-1}
[[ ! "$DEV" =~ ^[0-9]+$ ]] && DEV=1

echo ""
echo -e "${YELLOW}Tipo de expiración:${NC}"
echo -e "  [1] Días"
echo -e "  [2] Horas"
echo -e "  [3] Minutos"
read -p "Opción [1-3]: " TYPE

case $TYPE in
    1) read -p "Cantidad de días: " AMT; EXP=$(date -d "+$AMT days" '+%Y-%m-%d %H:%M:%S');;
    2) read -p "Cantidad de horas: " AMT; EXP=$(date -d "+$AMT hours" '+%Y-%m-%d %H:%M:%S');;
    3) read -p "Cantidad de minutos: " AMT; EXP=$(date -d "+$AMT minutes" '+%Y-%m-%d %H:%M:%S');;
    *) echo -e "${RED}[!] Opción inválida${NC}"; read -p "ENTER..."; return 1;;
esac

# Crear usuario
useradd -M -s /bin/false "$USER" 2>/dev/null
echo "$USER:$PASS" | chpasswd 2>/dev/null

AUTO_DEL=$(($(date -d "$EXP" +%s) + 172800))
CREATED=$(date '+%Y-%m-%d %H:%M:%S')
echo "$USER|$PASS|$DEV|$CREATED|$EXP|$AUTO_DEL" >> "$DB"

# Mostrar configuración
clear
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "        ${GREEN}✓ USUARIO CREADO EXITOSAMENTE${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}📡 INFORMACIÓN DEL SERVIDOR:${NC}"
echo -e "  • IP: ${GREEN}${IP}${NC}"
echo -e "  • Puerto WS: ${GREEN}80 / 443${NC}"
echo -e "  • Path: ${GREEN}/${NC}"
echo ""
echo -e "${CYAN}──────────────────────────────────────────────────${NC}"
echo -e "${YELLOW}👤 DATOS DEL USUARIO:${NC}"
echo -e "  • Usuario: ${GREEN}${BOLD}${USER}${NC}"
echo -e "  • Contraseña: ${GREEN}${BOLD}${PASS}${NC}"
echo -e "  • Dispositivos: ${GREEN}${BOLD}${DEV}${NC}"
echo -e "  • Expira: ${RED}${BOLD}${EXP}${NC}"
echo -e "${CYAN}──────────────────────────────────────────────────${NC}"
echo ""
echo -e "${GREEN}══════════════════════════════════════════════════${NC}"
echo -e "  ${GREEN}✓ Usuario creado correctamente${NC}"
echo -e "${GREEN}══════════════════════════════════════════════════${NC}"
echo ""
read -p "Presiona ENTER para continuar..."
}

list_users() {
clear
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "        ${GREEN}USUARIOS SSH${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo ""

[[ ! -f "$DB" ]] && { echo -e "${YELLOW}Sin usuarios registrados${NC}"; read -p "ENTER..."; return 0; }

printf "${YELLOW}%-15s %-10s %-10s %-20s${NC}\n" "Usuario" "Dispositivos" "Estado" "Expiración"
echo -e "${CYAN}────────────────────────────────────────────────────────${NC}"

while IFS='|' read -r user pass dev created exp auto; do
    [[ -z "$user" ]] && continue
    now=$(date +%s)
    exp_sec=$(date -d "$exp" +%s 2>/dev/null)
    
    if [[ $now -gt $auto ]]; then
        status="${RED}Eliminado${NC}"
    elif [[ $now -gt $exp_sec ]]; then
        status="${YELLOW}Expirado${NC}"
    else
        status="${GREEN}Activo${NC}"
    fi
    
    printf "${WHITE}%-15s${NC} %-10s ${status} %-20s\n" "$user" "$dev" "$exp"
done < "$DB"

echo ""
read -p "ENTER..."
}

del_user() {
read -p "Usuario a eliminar: " USER
[[ -z "$USER" ]] && { echo -e "${RED}[!] Nombre requerido${NC}"; read -p "ENTER..."; return 1; }

userdel -r "$USER" 2>/dev/null
[[ -f "$DB" ]] && { grep -v "^${USER}|" "$DB" > "${DB}.tmp"; mv "${DB}.tmp" "$DB"; }

echo -e "${GREEN}[OK] Usuario eliminado${NC}"
read -p "ENTER..."
}

while true; do
clear
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "        ${GREEN}SSH MANAGER${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo ""
echo -e "  [1] Crear Usuario"
echo -e "  [2] Eliminar Usuario"
echo -e "  [3] Ver Usuarios"
echo ""
echo -e "  [0] Regresar"
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo ""
read -p "Opción [0-3]: " opt

case $opt in
    1) create_user ;;
    2) del_user ;;
    3) list_users ;;
    0) break ;;
    *) echo -e "${RED}Opción inválida${NC}"; sleep 1 ;;
esac
done
