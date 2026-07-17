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
    curl -s https://api.ipify.org 2>/dev/null || curl -s https://ifconfig.me 2>/dev/null || echo "127.0.0.1"
}

get_domain() {
    if [[ -f /etc/oxgi/domain.conf ]]; then
        cat /etc/oxgi/domain.conf
    else
        echo "Sin dominio configurado"
    fi
}

calculate_expiry() {
    local type=$1
    local amount=$2
    local expiry_date=""
    
    case $type in
        1) # Meses
            expiry_date=$(date -d "+${amount} months" '+%Y-%m-%d %H:%M:%S' 2>/dev/null)
            if [[ $? -ne 0 ]]; then
                expiry_date=$(date -v+${amount}m '+%Y-%m-%d %H:%M:%S' 2>/dev/null)
            fi
            ;;
        2) # Días
            expiry_date=$(date -d "+${amount} days" '+%Y-%m-%d %H:%M:%S' 2>/dev/null)
            if [[ $? -ne 0 ]]; then
                expiry_date=$(date -v+${amount}d '+%Y-%m-%d %H:%M:%S' 2>/dev/null)
            fi
            ;;
        3) # Horas
            expiry_date=$(date -d "+${amount} hours" '+%Y-%m-%d %H:%M:%S' 2>/dev/null)
            if [[ $? -ne 0 ]]; then
                expiry_date=$(date -v+${amount}H '+%Y-%m-%d %H:%M:%S' 2>/dev/null)
            fi
            ;;
        4) # Minutos
            expiry_date=$(date -d "+${amount} minutes" '+%Y-%m-%d %H:%M:%S' 2>/dev/null)
            if [[ $? -ne 0 ]]; then
                expiry_date=$(date -v+${amount}M '+%Y-%m-%d %H:%M:%S' 2>/dev/null)
            fi
            ;;
    esac
    
    echo "$expiry_date"
}

create_user() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "        ${GREEN}${BOLD}CREAR USUARIO SSH${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo ""
    
    # 1. Nombre de usuario
    read -p "$(echo -e ${YELLOW}Nombre de usuario:${NC} ")" USERNAME
    
    if [[ -z "$USERNAME" ]]; then
        echo -e "${RED}[!] Datos incompletos.${NC}"
        read -p "Presiona ENTER para continuar..."
        return 1
    fi
    
    # Verificar si el usuario ya existe
    if id "$USERNAME" &>/dev/null; then
        echo -e "${RED}[!] El usuario '$USERNAME' ya existe.${NC}"
        read -p "Presiona ENTER para continuar..."
        return 1
    fi
    
    # 2. Contraseña
    read -sp "$(echo -e ${YELLOW}Contraseña:${NC} ")" PASSWORD
    echo ""
    
    if [[ -z "$PASSWORD" ]]; then
        echo -e "${RED}[!] Datos incompletos.${NC}"
        read -p "Presiona ENTER para continuar..."
        return 1
    fi
    
    # 3. Dispositivos permitidos (por defecto 1)
    echo ""
    read -p "$(echo -e ${YELLOW}Dispositivos permitidos [por defecto 1]:${NC} ")" DEVICES
    DEVICES=${DEVICES:-1}
    
    if ! [[ "$DEVICES" =~ ^[0-9]+$ ]] || [[ "$DEVICES" -lt 1 ]]; then
        DEVICES=1
    fi
    
    # 4. Tipo de tiempo de expiración
    echo ""
    echo -e "${YELLOW}Elija el tipo de tiempo:${NC}"
    echo -e "  ${GREEN}[1]${NC} Meses (ms)"
    echo -e "  ${GREEN}[2]${NC} Días (ds)"
    echo -e "  ${GREEN}[3]${NC} Horas (hr)"
    echo -e "  ${GREEN}[4]${NC} Minutos (mt)"
    echo ""
    read -p "Opción [1-4]: " TIME_TYPE
    
    if ! [[ "$TIME_TYPE" =~ ^[1-4]$ ]]; then
        echo -e "${RED}[!] Opción inválida.${NC}"
        read -p "Presiona ENTER para continuar..."
        return 1
    fi
    
    # 5. Cantidad de tiempo
    echo ""
    read -p "$(echo -e ${YELLOW}¿Cuánto tiempo?:${NC} ")" TIME_AMOUNT
    
    if ! [[ "$TIME_AMOUNT" =~ ^[0-9]+$ ]] || [[ "$TIME_AMOUNT" -lt 1 ]]; then
        echo -e "${RED}[!] Cantidad inválida.${NC}"
        read -p "Presiona ENTER para continuar..."
        return 1
    fi
    
    # Calcular fecha de expiración
    EXPIRY_DATE=$(calculate_expiry $TIME_TYPE $TIME_AMOUNT)
    EXPIRY_TIMESTAMP=$(date -d "$EXPIRY_DATE" +%s 2>/dev/null)
    
    if [[ $? -ne 0 ]]; then
        EXPIRY_TIMESTAMP=$(date -j -f "%Y-%m-%d %H:%M:%S" "$EXPIRY_DATE" +%s 2>/dev/null)
    fi
    
    # Calcular fecha de eliminación automática (2 días después de expirar)
    AUTO_DELETE_TIMESTAMP=$((EXPIRY_TIMESTAMP + 172800)) # 172800 segundos = 2 días
    AUTO_DELETE_DATE=$(date -d "@$AUTO_DELETE_TIMESTAMP" '+%Y-%m-%d %H:%M:%S' 2>/dev/null)
    
    # Crear usuario en el sistema
    useradd -M -s /bin/false -e $(date -d "$EXPIRY_DATE" '+%Y-%m-%d' 2>/dev/null) "$USERNAME" 2>/dev/null
    if [[ $? -ne 0 ]]; then
        # Intentar sin fecha de expiración en useradd (para sistemas que no lo soportan)
        useradd -M -s /bin/false "$USERNAME" 2>/dev/null
    fi
    
    echo "$USERNAME:$PASSWORD" | chpasswd 2>/dev/null
    
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}[!] Error al crear el usuario.${NC}"
        read -p "Presiona ENTER para continuar..."
        return 1
    fi
    
    # Guardar en base de datos
    # Formato: usuario|contraseña|dispositivos|fecha_creacion|fecha_expiracion|auto_delete_timestamp
    CREATED_DATE=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${USERNAME}|${PASSWORD}|${DEVICES}|${CREATED_DATE}|${EXPIRY_DATE}|${AUTO_DELETE_TIMESTAMP}" >> "$DB_FILE"
    
    # Obtener IP y dominio
    SERVER_IP=$(get_ip)
    SERVER_DOMAIN=$(get_domain)
    
    # Mostrar resumen
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "        ${GREEN}${BOLD}¡USUARIO CREADO EXITOSAMENTE!${NC}"
    echo -e "        ${GREEN}✓${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}📡 INFORMACIÓN DEL SERVIDOR:${NC}"
    echo -e "  • Dominio: ${WHITE}${SERVER_DOMAIN}${NC}"
    echo -e "  • IP: ${WHITE}${SERVER_IP}${NC}"
    echo ""
    echo -e "${CYAN}──────────────────────────────────────────────────${NC}"
    echo -e "${YELLOW} DATOS DEL USUARIO:${NC}"
    echo -e "  • Usuario: ${GREEN}${BOLD}${USERNAME}${NC}"
    echo -e "  • Contraseña: ${GREEN}${BOLD}${PASSWORD}${NC}"
    echo -e "  • Dispositivos permitidos: ${GREEN}${BOLD}${DEVICES}${NC}"
    echo -e "  • Fecha de expiración: ${RED}${BOLD}${EXPIRY_DATE}${NC}"
    echo -e "  • Eliminación automática: ${YELLOW}${AUTO_DELETE_DATE}${NC}"
    echo -e "${CYAN}──────────────────────────────────────────────────${NC}"
    echo ""
    echo -e "${GREEN}══════════════════════════════════════════════════${NC}"
    echo -e "  ${GREEN}✓ Usuario creado correctamente${NC}"
    echo -e "${GREEN}══════════════════════════════════════════════════${NC}"
    echo ""
    
    read -p "Presiona ENTER para continuar..."
}

delete_user() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "        ${RED}${BOLD}ELIMINAR USUARIO SSH${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo ""
    
    read -p "$(echo -e ${YELLOW}Nombre del usuario a eliminar:${NC} ")" USERNAME
    
    if [[ -z "$USERNAME" ]]; then
        echo -e "${RED}[!] Nombre de usuario requerido.${NC}"
        read -p "Presiona ENTER para continuar..."
        return 1
    fi
    
    # Eliminar usuario del sistema
    userdel -r "$USERNAME" 2>/dev/null
    
    # Eliminar de la base de datos
    if [[ -f "$DB_FILE" ]]; then
        grep -v "^${USERNAME}|" "$DB_FILE" > "${DB_FILE}.tmp"
        mv "${DB_FILE}.tmp" "$DB_FILE"
    fi
    
    echo -e "${GREEN}[OK] Usuario '${USERNAME}' eliminado.${NC}"
    read -p "Presiona ENTER para continuar..."
}

list_users() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "        ${GREEN}${BOLD}USUARIOS SSH REGISTRADOS${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo ""
    
    if [[ ! -f "$DB_FILE" ]] || [[ ! -s "$DB_FILE" ]]; then
        echo -e "${YELLOW}No hay usuarios registrados.${NC}"
        echo ""
        read -p "Presiona ENTER para continuar..."
        return 0
    fi
    
    printf "${YELLOW}%-15s %-12s %-10s %-20s %-20s${NC}\n" "Usuario" "Dispositivos" "Estado" "Expiración" "Auto-Eliminación"
    echo -e "${CYAN}────────────────────────────────────────────────────────────────────────────────${NC}"
    
    while IFS='|' read -r user pass devices created expiry auto_delete_ts; do
        if [[ -n "$user" ]]; then
            # Verificar si está expirado
            current_ts=$(date +%s)
            if [[ "$current_ts" -gt "$auto_delete_ts" ]]; then
                status="${RED}Eliminado${NC}"
            elif [[ "$current_ts" -gt "$expiry" ]]; then
                status="${YELLOW}Expirado${NC}"
            else
                status="${GREEN}Activo${NC}"
            fi
            
            # Formatear fecha de auto-eliminación
            auto_delete_date=$(date -d "@$auto_delete_ts" '+%Y-%m-%d %H:%M' 2>/dev/null)
            
            printf "${WHITE}%-15s${NC} %-12s ${status} %-20s %-20s\n" \
                "$user" "$devices" "$expiry" "$auto_delete_date"
        fi
    done < "$DB_FILE"
    
    echo ""
    read -p "Presiona ENTER para continuar..."
}

check_expired_users() {
    # Esta función verifica y elimina usuarios que tienen 2 días de expirados
    if [[ ! -f "$DB_FILE" ]]; then
        return 0
    fi
    
    current_ts=$(date +%s)
    local temp_file="${DB_FILE}.tmp"
    local found_expired=0
    
    > "$temp_file"
    
    while IFS='|' read -r user pass devices created expiry auto_delete_ts; do
        if [[ -n "$user" ]]; then
            if [[ "$current_ts" -gt "$auto_delete_ts" ]]; then
                # Eliminar usuario del sistema
                userdel -r "$user" 2>/dev/null
                echo -e "${RED}[AUTO-DELETE] Usuario '${user}' eliminado (2 días después de expirar)${NC}"
                found_expired=1
            else
                # Mantener usuario
                echo "${user}|${pass}|${devices}|${created}|${expiry}|${auto_delete_ts}" >> "$temp_file"
            fi
        fi
    done < "$DB_FILE"
    
    mv "$temp_file" "$DB_FILE"
    
    if [[ $found_expired -eq 1 ]]; then
        echo -e "${GREEN}[OK] Verificación completada.${NC}"
    fi
}

renew_user() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "        ${GREEN}${BOLD}RENOVAR USUARIO SSH${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo ""
    
    read -p "$(echo -e ${YELLOW}Nombre del usuario:${NC} ")" USERNAME
    
    if [[ -z "$USERNAME" ]] || ! grep -q "^${USERNAME}|" "$DB_FILE" 2>/dev/null; then
        echo -e "${RED}[!] Usuario no encontrado.${NC}"
        read -p "Presiona ENTER para continuar..."
        return 1
    fi
    
    # Tipo de renovación
    echo ""
    echo -e "${YELLOW}Elija el tipo de tiempo:${NC}"
    echo -e "  ${GREEN}[1]${NC} Meses (ms)"
    echo -e "  ${GREEN}[2]${NC} Días (ds)"
    echo -e "  ${GREEN}[3]${NC} Horas (hr)"
    echo -e "  ${GREEN}[4]${NC} Minutos (mt)"
    echo ""
    read -p "Opción [1-4]: " TIME_TYPE
    
    if ! [[ "$TIME_TYPE" =~ ^[1-4]$ ]]; then
        echo -e "${RED}[!] Opción inválida.${NC}"
        read -p "Presiona ENTER para continuar..."
        return 1
    fi
    
    echo ""
    read -p "$(echo -e ${YELLOW}¿Cuánto tiempo?:${NC} ")" TIME_AMOUNT
    
    if ! [[ "$TIME_AMOUNT" =~ ^[0-9]+$ ]] || [[ "$TIME_AMOUNT" -lt 1 ]]; then
        echo -e "${RED}[!] Cantidad inválida.${NC}"
        read -p "Presiona ENTER para continuar..."
        return 1
    fi
    
    # Calcular nueva fecha de expiración
    NEW_EXPIRY=$(calculate_expiry $TIME_TYPE $TIME_AMOUNT)
    NEW_AUTO_DELETE_TS=$(($(date -d "$NEW_EXPIRY" +%s 2>/dev/null) + 172800))
    
    # Actualizar en la base de datos
    if [[ -f "$DB_FILE" ]]; then
        local temp_file="${DB_FILE}.tmp"
        > "$temp_file"
        
        while IFS='|' read -r user pass devices created expiry auto_delete_ts; do
            if [[ "$user" == "$USERNAME" ]]; then
                echo "${user}|${pass}|${devices}|${created}|${NEW_EXPIRY}|${NEW_AUTO_DELETE_TS}" >> "$temp_file"
            else
                echo "${user}|${pass}|${devices}|${created}|${expiry}|${auto_delete_ts}" >> "$temp_file"
            fi
        done < "$DB_FILE"
        
        mv "$temp_file" "$DB_FILE"
    fi
    
    echo -e "${GREEN}[OK] Usuario '${USERNAME}' renovado hasta: ${NEW_EXPIRY}${NC}"
    read -p "Presiona ENTER para continuar..."
}

# Menú principal
while true; do
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "        ${GREEN}${BOLD}SSH MANAGER${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${GREEN}[1]${NC} Crear Usuario"
    echo -e "  ${GREEN}[2]${NC} Eliminar Usuario"
    echo -e "  ${GREEN}[3]${NC} Ver Usuarios"
    echo -e "  ${GREEN}[4]${NC} Renovar Usuario"
    echo -e "  ${GREEN}[5]${NC} Verificar Usuarios Expirados"
    echo ""
    echo -e "  ${RED}[0]${NC} Regresar"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo ""
    read -p "Opción [0-5]: " opt

    case $opt in
        1) create_user ;;
        2) delete_user ;;
        3) list_users ;;
        4) renew_user ;;
        5) 
            echo -e "${YELLOW}[*] Verificando usuarios expirados...${NC}"
            check_expired_users
            read -p "Presiona ENTER para continuar..."
            ;;
        0) break ;;
        *) echo -e "${RED}Opción inválida.${NC}"; sleep 1 ;;
    esac
done
