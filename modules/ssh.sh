#!/bin/bash

if [[ $EUID -ne 0 ]]; then
   echo -e "\e[31m[ERROR] Requiere root.${NC}\e[0m"
   exit 1
fi

GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

DB_FILE="/etc/oxgi/ssh_users.db"
mkdir -p /etc/oxgi

create_user() {
    clear
    echo -e "${GREEN}══════════════════════════════════════${NC}"
    echo -e "      CREAR USUARIO SSH"
    echo -e "${GREEN}══════════════════════════════════════${NC}"
    echo ""
    read -p "Nombre de usuario: " USERNAME
    read -sp "Contraseña: " PASSWORD
    echo ""
    read -p "Días de validez: " DAYS
    
    if [[ -z "$USERNAME" || -z "$PASSWORD" ]]; then
        echo -e "${RED}[!] Datos incompletos.${NC}"
        read -p "Presiona ENTER..."
        return 1
    fi
    
    DAYS=${DAYS:-30}
    EXPIRY_DATE=$(date -d "+${DAYS} days" +%Y-%m-%d 2>/dev/null || date -v+${DAYS}d +%Y-%m-%d 2>/dev/null)
    
    useradd -M -s /bin/false -e $EXPIRY_DATE $USERNAME 2>/dev/null || {
        echo -e "${RED}[!] El usuario ya existe.${NC}"
        read -p "Presiona ENTER..."
        return 1
    }
    
    echo "$USERNAME:$PASSWORD" | chpasswd
    echo "${USERNAME}|${PASSWORD}|${EXPIRY_DATE}|$(date +%s)" >> $DB_FILE
    
    echo -e "${GREEN}[OK] Usuario creado. Expira: $EXPIRY_DATE${NC}"
    read -p "Presiona ENTER..."
}

delete_user() {
    read -p "Usuario a eliminar: " USERNAME
    userdel -r $USERNAME 2>/dev/null
    sed -i "/^${USERNAME}|/d" $DB_FILE
    echo -e "${GREEN}[OK] Usuario eliminado.${NC}"
    read -p "Presiona ENTER..."
}

list_users() {
    clear
    echo -e "${GREEN}══════════════════════════════════════${NC}"
    echo -e "      USUARIOS SSH"
    echo -e "${GREEN}══════════════════════════════════════${NC}"
    echo ""
    if [[ -f $DB_FILE ]]; then
        printf "${YELLOW}%-15s %-15s %-12s${NC}\n" "Usuario" "Contraseña" "Expira"
        echo "────────────────────────────────────────"
        while IFS='|' read -r user pass expiry date; do
            printf "${GREEN}%-15s${NC} %-15s %-12s\n" "$user" "$pass" "$expiry"
        done < $DB_FILE
    else
        echo -e "${RED}No hay usuarios.${NC}"
    fi
    echo ""
    read -p "Presiona ENTER..."
}

check_expired() {
    echo -e "${YELLOW}[*] Verificando usuarios expirados...${NC}"
    if [[ -f $DB_FILE ]]; then
        while IFS='|' read -r user pass expiry date; do
            if [[ $(date -d "$expiry" +%s 2>/dev/null) -lt $(date +%s) ]]; then
                echo -e "${RED}Eliminando usuario expirado: $user${NC}"
                userdel -r $user 2>/dev/null
                sed -i "/^${user}|/d" $DB_FILE
            fi
        done < $DB_FILE
    fi
    echo -e "${GREEN}[OK] Verificación completada.${NC}"
    read -p "Presiona ENTER..."
}

while true; do
    clear
    echo "══════════════════════════════════════"
    echo -e "        ${GREEN}SSH MANAGER${NC}"
    echo "══════════════════════════════════════"
    echo ""
    echo -e "  [1] ${GREEN}Crear Usuario${NC}"
    echo -e "  [2] ${RED}Eliminar Usuario${NC}"
    echo -e "  [3] ${YELLOW}Ver Usuarios${NC}"
    echo -e "  [4] ${YELLOW}Verificar Expirados${NC}"
    echo ""
    echo -e "  [0] ${NC}Regresar"
    echo "══════════════════════════════════════"
    read -p "Opción [0-4]: " opt

    case $opt in
        1) create_user ;;
        2) delete_user ;;
        3) list_users ;;
        4) check_expired ;;
        0) break ;;
        *) echo -e "${RED}Inválida${NC}"; sleep 1 ;;
    esac
done
