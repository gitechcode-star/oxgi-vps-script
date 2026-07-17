#!/bin/bash

# Verificar root
if [[ $EUID -ne 0 ]]; then
    echo -e "\e[31m[ERROR] Este script debe ejecutarse como root\e[0m"
    exit 1
fi

GREEN='\033[1;32m'
RED='\033[1;31m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'
NC='\033[0m'
BOLD='\033[1m'

DB="/etc/oxgi/ssh_users.db"
mkdir -p /etc/oxgi

IP=$(curl -s https://api.ipify.org 2>/dev/null || echo "127.0.0.1")

create_user() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "        ${GREEN}${BOLD}CREAR USUARIO SSH${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo ""
    
    # Técnica a prueba de fallos: echo separado de read
    echo -ne "${YELLOW}➤ Nombre de usuario: ${NC}"
    read USER
    
    if [[ -z "$USER" ]]; then
        echo -e "${RED}[!] El nombre de usuario no puede estar vacío.${NC}"
        echo -e "${YELLOW}Presiona ENTER para continuar...${NC}"
        read
        return 1
    fi

    if id "$USER" &>/dev/null; then
        echo -e "${RED}[!] El usuario '$USER' ya existe en el sistema.${NC}"
        echo -e "${YELLOW}Presiona ENTER para continuar...${NC}"
        read
        return 1
    fi

    echo -ne "${YELLOW}➤ Contraseña: ${NC}"
    read -s PASS
    echo ""
    
    if [[ -z "$PASS" ]]; then
        echo -e "${RED}[!] La contraseña no puede estar vacía.${NC}"
        echo -e "${YELLOW}Presiona ENTER para continuar...${NC}"
        read
        return 1
    fi

    echo ""
    echo -ne "${YELLOW}➤ Dispositivos permitidos (por defecto 1): ${NC}"
    read DEV
    DEV=${DEV:-1}
    
    if ! [[ "$DEV" =~ ^[0-9]+$ ]]; then
        DEV=1
    fi

    echo ""
    echo -e "${YELLOW}Seleccione el tipo de expiración:${NC}"
    echo -e "  ${GREEN}[1]${NC} Días"
    echo -e "  ${GREEN}[2]${NC} Horas"
    echo -e "  ${GREEN}[3]${NC} Minutos"
    echo ""
    echo -ne "${YELLOW}➤ Opción [1-3]: ${NC}"
    read TYPE

    case $TYPE in
        1) 
            echo -ne "${YELLOW}➤ Cantidad de días: ${NC}"
            read AMT
            EXP=$(date -d "+$AMT days" '+%Y-%m-%d %H:%M:%S' 2>/dev/null)
            ;;
        2) 
            echo -ne "${YELLOW}➤ Cantidad de horas: ${NC}"
            read AMT
            EXP=$(date -d "+$AMT hours" '+%Y-%m-%d %H:%M:%S' 2>/dev/null)
            ;;
        3) 
            echo -ne "${YELLOW}➤ Cantidad de minutos: ${NC}"
            read AMT
            EXP=$(date -d "+$AMT minutes" '+%Y-%m-%d %H:%M:%S' 2>/dev/null)
            ;;
        *) 
            echo -e "${RED}[!] Opción inválida.${NC}"
            echo -e "${YELLOW}Presiona ENTER para continuar...${NC}"
            read
            return 1
            ;;
    esac

    if [[ -z "$AMT" ]] || ! [[ "$AMT" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}[!] Cantidad inválida.${NC}"
        echo -e "${YELLOW}Presiona ENTER para continuar...${NC}"
        read
        return 1
    fi

    # Crear usuario en el sistema
    useradd -M -s /bin/false "$USER" 2>/dev/null
    echo "$USER:$PASS" | chpasswd 2>/dev/null

    # Calcular fecha de auto-eliminación (2 días después de la expiración = 172800 segundos)
    EXP_SEC=$(date -d "$EXP" +%s 2>/dev/null)
    AUTO_DEL=$((EXP_SEC + 172800))
    CREATED=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Guardar en la base de datos
    echo "$USER|$PASS|$DEV|$CREATED|$EXP|$AUTO_DEL" >> "$DB"

    # Mostrar resumen
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "        ${GREEN}${BOLD}✓ USUARIO CREADO EXITOSAMENTE${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}📡 INFORMACIÓN DEL SERVIDOR:${NC}"
    echo -e "  • IP: ${WHITE}${IP}${NC}"
    echo -e "  • Puerto WS: ${WHITE}80 / 443${NC}"
    echo -e "  • Path: ${WHITE}/${NC}"
    echo ""
    echo -e "${CYAN}──────────────────────────────────────────────────${NC}"
    echo -e "${YELLOW}👤 DATOS DEL USUARIO:${NC}"
    echo -e "  • Usuario: ${GREEN}${BOLD}${USER}${NC}"
    echo -e "  • Contraseña: ${GREEN}${BOLD}${PASS}${NC}"
    echo -e "  • Dispositivos: ${GREEN}${BOLD}${DEV}${NC}"
    echo -e "  • Expira: ${RED}${BOLD}${EXP}${NC}"
    echo -e "${CYAN}──────────────────────────────────────────────────${NC}"
    echo ""
    echo -e "${YELLOW}Presiona ENTER para regresar al menú...${NC}"
    read
}

list_users() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "        ${GREEN}${BOLD}USUARIOS SSH REGISTRADOS${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo ""

    if [[ ! -f "$DB" ]] || [[ ! -s "$DB" ]]; then
        echo -e "${YELLOW}No hay usuarios registrados en el sistema.${NC}"
        echo ""
        echo -e "${YELLOW}Presiona ENTER para continuar...${NC}"
        read
        return 0
    fi

    printf "${YELLOW}%-15s %-12s %-10s %-20s${NC}\n" "Usuario" "Dispositivos" "Estado" "Expiración"
    echo -e "${CYAN}────────────────────────────────────────────────────────────────${NC}"

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
        
        printf "${WHITE}%-15s${NC} %-12s ${status} %-20s\n" "$user" "$dev" "$exp"
    done < "$DB"

    echo ""
    echo -e "${YELLOW}Presiona ENTER para continuar...${NC}"
    read
}

del_user() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "        ${RED}${BOLD}ELIMINAR USUARIO SSH${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo ""
    
    echo -ne "${YELLOW}➤ Nombre del usuario a eliminar: ${NC}"
    read USER
    
    if [[ -z "$USER" ]]; then
        echo -e "${RED}[!] El nombre no puede estar vacío.${NC}"
        echo -e "${YELLOW}Presiona ENTER para continuar...${NC}"
        read
        return 1
    fi

    userdel -r "$USER" 2>/dev/null
    
    if [[ -f "$DB" ]]; then
        grep -v "^${USER}|" "$DB" > "${DB}.tmp" 2>/dev/null
        mv "${DB}.tmp" "$DB" 2>/dev/null
    fi

    echo -e "${GREEN}[OK] El usuario '${USER}' ha sido eliminado.${NC}"
    echo -e "${YELLOW}Presiona ENTER para continuar...${NC}"
    read
}

# Menú principal del módulo
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
    echo -e "  ${RED}[0]${NC} Regresar al menú principal"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo ""
    echo -ne "${YELLOW}➤ Seleccione una opción [0-3]: ${NC}"
    read opt

    case $opt in
        1) create_user ;;
        2) del_user ;;
        3) list_users ;;
        0) break ;;
        *) 
            echo -e "${RED}Opción inválida.${NC}"
            sleep 1
            ;;
    esac
done
