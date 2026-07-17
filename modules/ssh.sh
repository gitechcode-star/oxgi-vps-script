#!/bin/bash

# Cargar módulos de interfaz
source /usr/local/oxgi/modules/color.sh
source /usr/local/oxgi/modules/header.sh

# Definir cajas más anchas para acomodar la nueva columna (80 caracteres)
BOX_TOP="┌────────────────────────────────────────────────────────────────────────"
BOX_BOT="└────────────────────────────────────────────────────────────────────────"
BOX_LINE="────────────────────────────────────────────────────────────────────────"

# Archivo de base de datos local
mkdir -p /etc/oxgi
DB_FILE="/etc/oxgi/ssh_users.db"
V2RAY_DB="/etc/oxgi/v2ray_users.db"
touch "$DB_FILE"
touch "$V2RAY_DB"

# Crear script de shell personalizado para limitar conexiones
SHELL_SCRIPT="/usr/local/oxgi/bin/oxgi-ssh-shell"
mkdir -p /usr/local/oxgi/bin

cat << 'EOF' > "$SHELL_SCRIPT"
#!/bin/bash
USER_NAME=$(whoami)
DB_FILE="/etc/oxgi/ssh_users.db"

# Leer límite desde la base de datos (campo 4)
MAX=$(grep "^${USER_NAME}:" "$DB_FILE" 2>/dev/null | head -1 | cut -d':' -f4)

# Si no existe en la DB o está vacío, default a 1
if [[ -z "$MAX" ]] || [[ "$MAX" -le 0 ]]; then
    MAX=1
fi

# Contar conexiones SSH activas para este usuario
CURRENT=$(who | grep "^${USER_NAME} " | wc -l)

# Si who no muestra nada, intentar con ps
if [[ "$CURRENT" -eq 0 ]]; then
    CURRENT=$(ps -u "$USER_NAME" sshd -o pid= 2>/dev/null | wc -l)
fi

if [[ "$CURRENT" -ge "$MAX" ]]; then
    echo ""
    echo "══════════════════════════════════════════════════════════════╗"
    echo "                    CONEXIÓN RECHAZADA                        ║"
    echo "╠══════════════════════════════════════════════════════════════"
    echo "  Límite de $MAX dispositivo(s) alcanzado.                     "
    echo "  Conexiones activas: $CURRENT                                 "
    echo "  Desconecte un dispositivo antes de intentar nuevamente.     "
    echo "══════════════════════════════════════════════════════════════╝"
    echo ""
    sleep 5
    exit 1
fi

# Mantener conexión viva para túneles/proxy
exec /bin/bash --login
EOF

chmod +x "$SHELL_SCRIPT"

# Agregar a shells permitidos si no está
if ! grep -q "$SHELL_SCRIPT" /etc/shells 2>/dev/null; then
    echo "$SHELL_SCRIPT" >> /etc/shells
fi

# Función auxiliar para validar nombre de usuario
validar_usuario() {
    if [[ ! "$1" =~ ^[a-zA-Z0-9_]+$ ]]; then
        echo -e "${RED}Error: El nombre de usuario solo puede contener letras, números y guiones bajos.${NC}"
        return 1
    fi
    if [[ ${#1} -lt 3 || ${#1} -gt 16 ]]; then
        echo -e "${RED}Error: El nombre de usuario debe tener entre 3 y 16 caracteres.${NC}"
        return 1
    fi
    return 0
}

# Función auxiliar para validar números enteros positivos (sin límite máximo)
validar_numero() {
    if [[ ! "$1" =~ ^[0-9]+$ ]] || [[ "$1" -le 0 ]]; then
        echo -e "${RED}Error: Debe ingresar un número entero válido mayor a 0.${NC}"
        return 1
    fi
    return 0
}

# Función para obtener puertos configurados
obtener_puertos() {
    local config_file="/etc/oxgi/config.conf"
    
    # Valores por defecto
    DOMAIN="No disponible"
    SSL_PORT="No disponible"
    DROPBEAR_PORT="No disponible"
    UDP_PORT="No disponible"
    OPENSSH_PORT="22"
    WEBSOCKET_PORT="No disponible"
    V2RAY_PORT="No disponible"
    
    if [[ -f "$config_file" ]]; then
        source "$config_file" 2>/dev/null
        
        # Dominio
        [[ -n "$DOMAIN" && "$DOMAIN" != "No disponible" ]] && DOMAIN="$DOMAIN"
        [[ -n "$DOMINIO" ]] && DOMAIN="$DOMINIO"
        [[ -n "$HOST" ]] && DOMAIN="$HOST"
        
        # Puertos
        [[ -n "$SSL_PORT" ]] && SSL_PORT="$SSL_PORT"
        [[ -n "$PUERTO_SSL" ]] && SSL_PORT="$PUERTO_SSL"
        
        [[ -n "$DROPBEAR_PORT" ]] && DROPBEAR_PORT="$DROPBEAR_PORT"
        [[ -n "$PUERTO_DROPBEAR" ]] && DROPBEAR_PORT="$PUERTO_DROPBEAR"
        
        [[ -n "$UDP_PORT" ]] && UDP_PORT="$UDP_PORT"
        [[ -n "$PUERTO_UDP" ]] && UDP_PORT="$PUERTO_UDP"
        
        [[ -n "$OPENSSH_PORT" ]] && OPENSSH_PORT="$OPENSSH_PORT"
        [[ -n "$PUERTO_SSH" ]] && OPENSSH_PORT="$PUERTO_SSH"
        
        [[ -n "$WEBSOCKET_PORT" ]] && WEBSOCKET_PORT="$WEBSOCKET_PORT"
        [[ -n "$PUERTO_WS" ]] && WEBSOCKET_PORT="$PUERTO_WS"
        
        [[ -n "$V2RAY_PORT" ]] && V2RAY_PORT="$V2RAY_PORT"
        [[ -n "$PUERTO_V2RAY" ]] && V2RAY_PORT="$PUERTO_V2RAY"
    fi
}

# Función para crear usuarios V2Ray con protocolo específico
crear_usuario_v2ray() {
    local protocol_type="$1"
    clear
    show_header
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║ Crear Usuario V2Ray ($protocol_type)                           ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    read -p "Nombre de usuario: " username
    validar_usuario "$username" || { read -p "ENTER para continuar..."; return; }
    
    if grep -q "^${username}:" "$V2RAY_DB" 2>/dev/null; then
        echo -e "${RED}Error: El usuario V2Ray '$username' ya existe.${NC}"
        read -p "ENTER para continuar..."
        return
    fi

    uuid=$(cat /proc/sys/kernel/random/uuid)
    echo "UUID generado: $uuid"

    echo
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║ Seleccione la unidad de tiempo:                              ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo -e "${CYAN}║ [1] Minutos                                                  ║${NC}"
    echo -e "${CYAN}║ [2] Horas                                                    ║${NC}"
    echo -e "${CYAN}║ [3] Días                                                     ║${NC}"
    echo -e "${CYAN}║ [4] Meses (30 días)                                          ║${NC}"
    
    read -p "Opción: " unit_opt
    
    case $unit_opt in
        1) unit_str="minutes" ;;
        2) unit_str="hours" ;;
        3) unit_str="days" ;;
        4) unit_str="days" ;;
        *) 
            echo -e "${RED}Opción inválida.${NC}"
            read -p "ENTER para continuar..."
            return 
            ;;
    esac

    read -p "Cantidad: " time_qty
    validar_numero "$time_qty" || { read -p "ENTER para continuar..."; return; }

    if [[ "$unit_opt" == "4" ]]; then
        time_qty=$((time_qty * 30))
    fi

    exp_datetime=$(date -d "+$time_qty $unit_str" "+%Y-%m-%d %H:%M:%S")
    exp_epoch=$(date -d "+$time_qty $unit_str" +%s)

    # Formato: usuario:uuid:protocolo:exp_epoch:exp_datetime:traffic
    echo "${username}:${uuid}:${protocol_type}:${exp_epoch}:${exp_datetime}:0" >> "$V2RAY_DB"

    echo
    echo -e "${GREEN}✅ Usuario V2Ray '$username' ($protocol_type) creado exitosamente.${NC}"
    echo "UUID: $uuid"
    echo "Expira el: $exp_datetime"
    echo
    read -p "ENTER para continuar..."
}

while true; do
    clear
    show_header
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                          USER MANAGER                        ║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════╦═════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} SSH MANAGER                        ${CYAN}║${NC} XRAY / V2RAY MANAGER                  ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} [01] Crear Usuario SSH             ${CYAN}║${NC} [05] Crear Usuario xray / v2ray       ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} [02] Eliminar Usuario SSH          ${CYAN}║${NC} [13] Renovar Usuario V2Ray          ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} [03] Renovar Usuario SSH           ${CYAN}║${NC} [14] Eliminar Usuario V2Ray         ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} [04] Cambiar Contraseña SSH        ${CYAN}║${NC} [15] Lista de Usuarios V2Ray        ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} [05] Lista de Usuarios SSH         ${CYAN}║${NC} [16] Usuarios Online V2Ray          ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} [06] Usuarios Online SSH           ${CYAN}║${NC}                                    ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} [07] Eliminar Expirados            ${CYAN}║${NC}                                    ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════╩═════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} [00] Regresar                                                ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo

    read -p "Seleccione una opción: " opt

    case $opt in
        1)
            clear
            show_header
            echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${CYAN}║ Crear Usuario SSH                                            ║${NC}"
            echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
            echo
            
            read -p "Nombre de usuario: " username
            validar_usuario "$username" || { read -p "ENTER para continuar..."; continue; }
            
            if id "$username" &>/dev/null; then
                echo -e "${RED}Error: El usuario '$username' ya existe. Por favor, elija otro nombre.${NC}"
                read -p "ENTER para continuar..."
                continue
            fi

            read -p "Contraseña (dejar en blanco para generar una aleatoria): " password
            if [[ -z "$password" ]]; then
                password=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9' | head -c 10)
                echo "Contraseña generada: $password"
            fi

            echo
            echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${CYAN}║ Seleccione la unidad de tiempo:                              ║${NC}"
            echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
            echo -e "${CYAN}║ [1] Minutos                                                  ║${NC}"
            echo -e "${CYAN}║ [2] Horas                                                    ║${NC}"
            echo -e "${CYAN}║ [3] Días                                                     ║${NC}"
            echo -e "${CYAN}║ [4] Meses (30 días)                                          ║${NC}"
            
            read -p "Opción: " unit_opt
            
            case $unit_opt in
                1) unit_str="minutes" ;;
                2) unit_str="hours" ;;
                3) unit_str="days" ;;
                4) unit_str="days" ;;
                *) 
                    echo -e "${RED}Opción inválida.${NC}"
                    read -p "ENTER para continuar..."
                    continue 
                    ;;
            esac

            read -p "Cantidad: " time_qty
            validar_numero "$time_qty" || { read -p "ENTER para continuar..."; continue; }

            if [[ "$unit_opt" == "4" ]]; then
                time_qty=$((time_qty * 30))
            fi

            read -p "Número máximo de dispositivos: " max_devices
            
            if [[ ! "$max_devices" =~ ^[0-9]+$ ]] || [[ "$max_devices" -le 0 ]]; then
                echo -e "${RED}Error: El número de dispositivos debe ser un número entero mayor a 0.${NC}"
                read -p "ENTER para continuar..."
                continue
            fi

            exp_datetime=$(date -d "+$time_qty $unit_str" "+%Y-%m-%d %H:%M:%S")
            exp_date=$(date -d "+$time_qty $unit_str" +%Y-%m-%d)
            exp_epoch=$(date -d "+$time_qty $unit_str" +%s)

            useradd -M -s "$SHELL_SCRIPT" -e "$exp_date" "$username" 2>/dev/null
            if [[ $? -ne 0 ]]; then
                echo -e "${RED}Error al crear el usuario. Verifique que no exista.${NC}"
                read -p "ENTER para continuar..."
                continue
            fi
            
            echo "$username:$password" | chpasswd

            if [[ -f "$DB_FILE" ]]; then
                temp_file=$(mktemp)
                grep -v "^${username}:" "$DB_FILE" > "$temp_file" 2>/dev/null || true
                mv "$temp_file" "$DB_FILE"
            fi
            
            echo "${username}:${exp_epoch}:${exp_datetime}:${max_devices}" >> "$DB_FILE"

            obtener_puertos

            echo
            echo
            echo -e         "───────────────────────────────────────────────────────────────"
            echo -e "${GREEN}✅ Usuario creado exitosamente.${NC}"
            echo -e "${CYAN}║${NC} Dominio: $DOMAIN                                          ${CYAN}║${NC}"
            echo -e "${CYAN}║${NC} Usuario: $username                                         ${CYAN}║${NC}"
            echo -e "${CYAN}║${NC} Contraseña: $password                                      ${CYAN}║${NC}"
            echo -e "${CYAN}║${NC} Dispositivos máx: $max_devices                             ${CYAN}║${NC}"
            echo -e         "───────────────────────────────────────────────────────────────"
            echo -e "${CYAN}║${NC} SSL: $SSL_PORT                                            ${CYAN}║${NC}"
            echo -e "${CYAN}║${NC} DROPBEAR: $DROPBEAR_PORT                                  ${CYAN}║${NC}"
            echo -e "${CYAN}║${NC} UDP: $UDP_PORT                                            ${CYAN}║${NC}"
            echo -e "${CYAN}║${NC} OpenSSH: $OPENSSH_PORT                                    ${CYAN}║${NC}"
            echo -e "${CYAN}║${NC} WebSocket: $WEBSOCKET_PORT                                ${CYAN}║${NC}"
            echo -e "${CYAN}║${NC} V2Ray: $V2RAY_PORT                                        ${CYAN}║${NC}"
            echo -e "${CYAN}║${NC}                                                           ${CYAN}║${NC}"
            echo -e         "───────────────────────────────────────────────────────────────"
            echo
            
            echo -e "${CYAN}║${NC} Expira el: $exp_datetime                                  ${CYAN}║${NC}"
            
            echo
            read -p "ENTER para continuar..."
            ;;

        2)
            clear
            show_header
            echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${CYAN}║ Eliminar Usuario SSH                                         ║${NC}"
            echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
            echo
            
            users_list=$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd)
            
            if [[ -z "$users_list" ]]; then
                echo -e "${RED}No hay usuarios registrados en el sistema.${NC}"
                read -p "ENTER para continuar..."
                continue
            fi

            echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
            printf "${CYAN} %-5s %-15s %-24s %-10s ${NC}\n" "N°" "Usuario" "Expiración" "Estado"
            echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
            
            i=1
            declare -a user_array=()
            for user in $users_list; do
                user_array+=("$user")
                db_entry=$(grep "^${user}:" "$DB_FILE" 2>/dev/null | head -1)
                if [[ -n "$db_entry" ]]; then
                    exp_epoch=$(echo "$db_entry" | cut -d':' -f2)
                    exp_info=$(echo "$db_entry" | cut -d':' -f3- | cut -d' ' -f1,2)
                else
                    exp_info=$(chage -l "$user" | grep "Account expires" | cut -d: -f2 | xargs)
                    if [[ "$exp_info" != "never" ]]; then
                        exp_epoch=$(date -d "$exp_info" +%s 2>/dev/null)
                    else
                        exp_epoch=9999999999
                        exp_info="Nunca"
                    fi
                fi
                
                now_epoch=$(date +%s)
                if [[ "$exp_info" == "Nunca" ]]; then
                    status="${GREEN}Activo${NC}"
                elif [[ $exp_epoch -lt $now_epoch ]]; then
                    status="${RED}Expirado${NC}"
                else
                    status="${GREEN}Activo${NC}"
                fi
                
                printf "${CYAN} %-5s %-15s %-24s %-10b ${NC}\n" "$i" "$user" "$exp_info" "$status"
                ((i++))
            done
            echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
            echo
            
            read -p "Ingrese el/los número(s) de usuario a eliminar (ej: 1 o 1,2,3): " selection
            IFS=',' read -ra selected_indices <<< "$selection"
            
            valid_selection=true
            for idx in "${selected_indices[@]}"; do
                idx=$(echo "$idx" | tr -d ' ')
                if ! [[ "$idx" =~ ^[0-9]+$ ]] || [[ "$idx" -lt 1 ]] || [[ "$idx" -gt "${#user_array[@]}" ]]; then
                    valid_selection=false
                    break
                fi
            done
            
            if [[ "$valid_selection" == false ]] || [[ ${#selected_indices[@]} -eq 0 ]]; then
                echo -e "${RED}Error: Selección inválida.${NC}"
                read -p "ENTER para continuar..."
                continue
            fi
            
            echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
            read -p " ¿Está seguro de eliminar los usuarios seleccionados? (s/N): " confirm
            echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
            
            if [[ "$confirm" =~ ^[Ss]$ ]]; then
                for idx in "${selected_indices[@]}"; do
                    idx=$(echo "$idx" | tr -d ' ')
                    username="${user_array[$((idx-1))]}"
                    
                    userdel "$username" 2>/dev/null
                    if [[ -f "$DB_FILE" ]]; then
                        temp_file=$(mktemp)
                        grep -v "^${username}:" "$DB_FILE" > "$temp_file" 2>/dev/null || true
                        mv "$temp_file" "$DB_FILE"
                    fi
                    echo -e "${GREEN}✅ Usuario SSH '$username' eliminado correctamente.${NC}"
                done
            else
                echo -e "${YELLOW}Operación cancelada.${NC}"
            fi
            echo
            read -p "ENTER para continuar..."
            ;;

        3)
            clear
            show_header
            echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${CYAN}║ Renovar Usuario SSH                                          ║${NC}"
            echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
            echo
            
            users_list=$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd)
            
            if [[ -z "$users_list" ]]; then
                echo -e "${RED}No hay usuarios registrados en el sistema.${NC}"
                read -p "ENTER para continuar..."
                continue
            fi

            echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
            printf "${CYAN} %-5s %-15s %-24s %-10s ${NC}\n" "N°" "Usuario" "Expiración" "Estado"
            echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
            
            i=1
            declare -a user_array=()
            for user in $users_list; do
                user_array+=("$user")
                db_entry=$(grep "^${user}:" "$DB_FILE" 2>/dev/null | head -1)
                if [[ -n "$db_entry" ]]; then
                    exp_epoch=$(echo "$db_entry" | cut -d':' -f2)
                    exp_info=$(echo "$db_entry" | cut -d':' -f3- | cut -d' ' -f1,2)
                else
                    exp_info=$(chage -l "$user" | grep "Account expires" | cut -d: -f2 | xargs)
                    if [[ "$exp_info" != "never" ]]; then
                        exp_epoch=$(date -d "$exp_info" +%s 2>/dev/null)
                    else
                        exp_epoch=9999999999
                        exp_info="Nunca"
                    fi
                fi
                
                now_epoch=$(date +%s)
                if [[ "$exp_info" == "Nunca" ]]; then
                    status="${GREEN}Activo${NC}"
                elif [[ $exp_epoch -lt $now_epoch ]]; then
                    status="${RED}Expirado${NC}"
                else
                    status="${GREEN}Activo${NC}"
                fi
                
                printf "${CYAN} %-5s %-15s %-24s %-10b ${NC}\n" "$i" "$user" "$exp_info" "$status"
                ((i++))
            done
            echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
            echo
            
            read -p "Ingrese el/los número(s) de usuario a renovar (ej: 1 o 1,2,3): " selection
            IFS=',' read -ra selected_indices <<< "$selection"
            
            valid_selection=true
            for idx in "${selected_indices[@]}"; do
                idx=$(echo "$idx" | tr -d ' ')
                if ! [[ "$idx" =~ ^[0-9]+$ ]] || [[ "$idx" -lt 1 ]] || [[ "$idx" -gt "${#user_array[@]}" ]]; then
                    valid_selection=false
                    break
                fi
            done
            
            if [[ "$valid_selection" == false ]] || [[ ${#selected_indices[@]} -eq 0 ]]; then
                echo -e "${RED}Error: Selección inválida.${NC}"
                read -p "ENTER para continuar..."
                continue
            fi

            echo
            echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${CYAN}║ Seleccione la unidad de tiempo:                              ║${NC}"
            echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
            echo -e "${CYAN}║ [1] Minutos                                                  ║${NC}"
            echo -e "${CYAN}║ [2] Horas                                                    ║${NC}"
            echo -e "${CYAN}║ [3] Días                                                     ║${NC}"
            echo -e "${CYAN}║ [4] Meses (30 días)                                          ║${NC}"
           
            read -p "Opción: " unit_opt

            case $unit_opt in
                1) unit_str="minutes" ;;
                2) unit_str="hours" ;;
                3) unit_str="days" ;;
                4) unit_str="months" ;;
                *) 
                    echo -e "${RED}Opción inválida.${NC}"
                    read -p "ENTER para continuar..."
                    continue 
                    ;;
            esac

            read -p "Cantidad: " time_qty
            validar_numero "$time_qty" || { read -p "ENTER para continuar..."; continue; }

            read -p "Número máximo de dispositivos: " max_devices_input
            
            if [[ ! "$max_devices_input" =~ ^[0-9]+$ ]] || [[ "$max_devices_input" -le 0 ]]; then
                echo -e "${RED}Error: El número de dispositivos debe ser un número entero mayor a 0.${NC}"
                read -p "ENTER para continuar..."
                continue
            fi

            for idx in "${selected_indices[@]}"; do
                idx=$(echo "$idx" | tr -d ' ')
                username="${user_array[$((idx-1))]}"
                
                now_epoch=$(date +%s)
                
                case $unit_str in
                    minutes) 
                        add_seconds=$((time_qty * 60))
                        new_exp_epoch=$((now_epoch + add_seconds))
                        new_exp_datetime=$(date -d "@$new_exp_epoch" "+%Y-%m-%d %H:%M:%S")
                        ;;
                    hours)   
                        add_seconds=$((time_qty * 3600))
                        new_exp_epoch=$((now_epoch + add_seconds))
                        new_exp_datetime=$(date -d "@$new_exp_epoch" "+%Y-%m-%d %H:%M:%S")
                        ;;
                    days)    
                        add_seconds=$((time_qty * 86400))
                        new_exp_epoch=$((now_epoch + add_seconds))
                        new_exp_datetime=$(date -d "@$new_exp_epoch" "+%Y-%m-%d %H:%M:%S")
                        ;;
                    months)
                        new_exp_datetime=$(date -d "+$time_qty months" "+%Y-%m-%d %H:%M:%S")
                        new_exp_epoch=$(date -d "$new_exp_datetime" +%s)
                        ;;
                esac

                new_exp_date=$(echo "$new_exp_datetime" | cut -d' ' -f1)

                usermod -e "$new_exp_date" "$username" 2>/dev/null
                chage -E "$new_exp_date" "$username" 2>/dev/null
                
                if [[ -f "$DB_FILE" ]]; then
                    temp_file=$(mktemp)
                    grep -v "^${username}:" "$DB_FILE" > "$temp_file" 2>/dev/null || true
                    echo "${username}:${new_exp_epoch}:${new_exp_datetime}:${max_devices_input}" >> "$temp_file"
                    mv "$temp_file" "$DB_FILE"
                fi

                echo -e "${GREEN}✅ Usuario SSH '$username' renovado exitosamente.${NC}"
                echo "   Nueva expiración: $new_exp_datetime"
            done

            echo
            echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${CYAN}║ Renovación completada para los usuarios seleccionados. ✅    ║${NC}"
            echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
            echo
            read -p "ENTER para continuar..."
            ;;

        4)
            clear
            show_header
            echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${CYAN}║ Cambiar Contraseña SSH                                       ║${NC}"
            echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
            echo
            
            read -p "Nombre de usuario: " username
            validar_usuario "$username" || { read -p "ENTER para continuar..."; continue; }
            
            if ! id "$username" &>/dev/null; then
                echo -e "${RED}Error: El usuario '$username' no existe.${NC}"
                read -p "ENTER para continuar..."
                continue
            fi

            read -p "Nueva contraseña (dejar en blanco para generar una aleatoria): " new_password
            if [[ -z "$new_password" ]]; then
                new_password=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9' | head -c 10)
                echo "Contraseña generada: $new_password"
            fi

            echo "$username:$new_password" | chpasswd
            echo
            echo -e "${GREEN}✅ Contraseña de '$username' actualizada correctamente.${NC}"
            echo
            read -p "ENTER para continuar..."
            ;;

        5)
            clear
            show_header
            echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${CYAN}║ Lista de Usuarios SSH                                        ║${NC}"
            echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
            echo
            
            users_list=$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd)
            
            if [[ -z "$users_list" ]]; then
                echo -e "${RED}No hay usuarios registrados en el sistema.${NC}"
                echo
                read -p "ENTER para continuar..."
            else
                echo -e "${CYAN}┌────────────────────────────────────────────────────────────────────────┐${NC}"
                printf "%-15s %-15s %-12s\n" "Usuario" "Tiempo" "Estado"
                echo -e "${CYAN}├────────────────────────────────────────────────────────────────────────┤${NC}"
                
                for user in $users_list; do
                    exp_info=""
                    db_entry=$(grep "^${user}:" "$DB_FILE" 2>/dev/null | head -1)

                    if [[ -n "$db_entry" ]]; then
                        exp_epoch=$(echo "$db_entry" | cut -d':' -f2)
                        exp_datetime=$(echo "$db_entry" | cut -d':' -f3-)
                    else
                        exp_info=$(chage -l "$user" | grep "Account expires" | cut -d: -f2 | xargs)
                        if [[ "$exp_info" != "never" ]]; then
                            exp_epoch=$(date -d "$exp_info" +%s 2>/dev/null)
                            exp_datetime="$exp_info"
                        else
                            exp_epoch=9999999999
                            exp_datetime="Nunca"
                        fi
                    fi

                    now_epoch=$(date +%s)

                    if [[ "$exp_datetime" == "Nunca" ]]; then
                        status="online"
                        time_left="Nunca"
                    elif [[ $exp_epoch -le $now_epoch ]]; then
                        time_left="${RED}Expirado${NC}"
                        status="offline"
                    else
                        status="online"
                        diff=$((exp_epoch - now_epoch))

                        if [[ $diff -ge 2592000 ]]; then
                            months=$((diff / 2592000))
                            time_left="${months}ms"
                        elif [[ $diff -ge 86400 ]]; then
                            days=$((diff / 86400))
                            time_left="${days}d"
                        elif [[ $diff -ge 3600 ]]; then
                            hours=$((diff / 3600))
                            time_left="${hours}h"
                        elif [[ $diff -ge 60 ]]; then
                            minutes=$((diff / 60))
                            time_left="${minutes}mt"
                        else
                            time_left="${diff}sg"
                        fi
                    fi

                    printf "%-15s %-15b %-12s\n" "$user" "$time_left" "$status"
                done

                echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
                echo
                read -p "ENTER para continuar..."
            fi
            ;;

        6)
            clear
            show_header
            echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${CYAN}║ Usuarios Online SSH                                          ║${NC}"
            echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
            echo
            
            online_users=$(who | awk '{print $1}' | sort -u)
            
            if [[ -z "$online_users" ]]; then
                echo -e "${RED}No hay usuarios conectados en este momento.${NC}"
            else
                echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
                printf "${CYAN} %-20s %-15s ${NC}\n" "Usuario" "Dispositivos"
                echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
                for user in $online_users; do
                    current_dev=$(who | grep "^${user} " | wc -l)
                    printf "${CYAN} %-20s %-15s ${NC}\n" "$user" "$current_dev"
                done
                echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
            fi
            echo
            read -p "ENTER para continuar..."
            ;;

        7)
            clear
            show_header
            echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${CYAN}║ Eliminar Usuarios Expirados                                  ║${NC}"
            echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
            echo
            
            deleted_count=0
            current_epoch=$(date +%s)
            
            # Eliminar SSH expirados
            if [[ -f "$DB_FILE" ]]; then
                while IFS=':' read -r db_user db_epoch db_datetime db_max; do
                    if [[ -n "$db_user" ]]; then
                        if [[ "$db_epoch" -lt "$current_epoch" ]]; then
                            if id "$db_user" &>/dev/null; then
                                userdel "$db_user" 2>/dev/null
                                echo -e "${RED}️ Usuario SSH '$db_user' eliminado (Expiró: $db_datetime)${NC}"
                                ((deleted_count++))
                            fi
                        fi
                    fi
                done < "$DB_FILE"
                
                temp_file=$(mktemp)
                while IFS=':' read -r db_user db_epoch db_datetime db_max; do
                    if [[ "$db_epoch" -ge "$current_epoch" ]]; then
                        echo "${db_user}:${db_epoch}:${db_datetime}:${db_max}" >> "$temp_file"
                    fi
                done < "$DB_FILE"
                mv "$temp_file" "$DB_FILE"
            fi

            users_list=$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd)
            for user in $users_list; do
                if ! grep -q "^${user}:" "$DB_FILE" 2>/dev/null; then
                    exp_info=$(chage -l "$user" | grep "Account expires" | cut -d: -f2 | xargs)
                    if [[ "$exp_info" != "never" ]] && [[ -n "$exp_info" ]]; then
                        exp_epoch=$(date -d "$exp_info" +%s 2>/dev/null)
                        if [[ -n "$exp_epoch" ]] && [[ "$exp_epoch" -lt "$current_epoch" ]]; then
                            userdel "$user" 2>/dev/null
                            echo -e "${RED}️ Usuario SSH '$user' eliminado (Expiró: $exp_info)${NC}"
                            ((deleted_count++))
                        fi
                    fi
                fi
            done

            # Eliminar V2Ray expirados
            if [[ -f "$V2RAY_DB" ]]; then
                temp_file=$(mktemp)
                while IFS=':' read -r v_user v_uuid v_proto v_epoch v_datetime v_traffic; do
                    if [[ -n "$v_user" ]]; then
                        if [[ "$v_epoch" -lt "$current_epoch" ]]; then
                            echo -e "${RED}️ Usuario V2Ray '$v_user' eliminado (Expiró: $v_datetime)${NC}"
                            ((deleted_count++))
                        else
                            echo "${v_user}:${v_uuid}:${v_proto}:${v_epoch}:${v_datetime}:${v_traffic}" >> "$temp_file"
                        fi
                    fi
                done < "$V2RAY_DB"
                mv "$temp_file" "$V2RAY_DB"
            fi
            
            echo
            if [[ $deleted_count -eq 0 ]]; then
                echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
                echo -e "${CYAN}║ No se encontraron usuarios expirados.                         ║${NC}"
                echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
            else
                echo -e "${CYAN}║ Se eliminaron $deleted_count usuario(s) expirado(s).                  ${NC}"
            fi
            echo
            read -p "ENTER para continuar..."
            ;;

        8)
            clear
            show_header
            echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${CYAN}║                    XRAY / V2RAY MANAGER                      ║${NC}"
            echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
            echo
            echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${NC}"
            echo -e "${CYAN}│${NC} [01] Crear Usuario VLESS TCP                               ${CYAN}│${NC}"
            echo -e "${CYAN}│${NC} [02] Crear Usuario VLESS WS                                ${CYAN}│${NC}"
            echo -e "${CYAN}│${NC} [03] Crear Usuario VMESS WS                                ${CYAN}│${NC}"
            echo -e "${CYAN}│${NC} [04] Crear Usuario TROJAN WS                               ${CYAN}│${NC}"
            echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${NC}"
            echo
            read -p "Seleccione una opción: " v2ray_opt
            
            case $v2ray_opt in
                1) crear_usuario_v2ray "VLESS TCP" ;;
                2) crear_usuario_v2ray "VLESS WS" ;;
                3) crear_usuario_v2ray "VMESS WS" ;;
                4) crear_usuario_v2ray "TROJAN WS" ;;
                *)
                    echo -e "${RED}Opción inválida.${NC}"
                    sleep 1.5
                    ;;
            esac
            ;;

        9)
            clear
            show_header
            echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${CYAN}║ Renovar Usuario V2Ray                                        ║${NC}"
            echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
            echo
            
            if [[ ! -s "$V2RAY_DB" ]]; then
                echo -e "${RED}No hay usuarios V2Ray registrados.${NC}"
                read -p "ENTER para continuar..."
                continue
            fi

            echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
            printf "${CYAN} %-5s %-15s %-15s %-24s %-10s ${NC}\n" "N°" "Usuario" "Protocolo" "Expiración" "Estado"
            echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
            
            i=1
            declare -a v2ray_users=()
            while IFS=: read -r v_user v_uuid v_proto v_exp v_date v_traffic; do
                v2ray_users+=("$v_user")
                now_epoch=$(date +%s)
                if [[ "$v_exp" -le "$now_epoch" ]]; then
                    status="${RED}Expirado${NC}"
                else
                    status="${GREEN}Activo${NC}"
                fi
                printf "${CYAN} %-5s %-15s %-15s %-24s %-10b ${NC}\n" "$i" "$v_user" "$v_proto" "$v_date" "$status"
                ((i++))
            done < "$V2RAY_DB"
            echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
            echo
            
            read -p "Ingrese el/los número(s) de usuario a renovar (ej: 1 o 1,2,3): " selection
            IFS=',' read -ra selected_indices <<< "$selection"
            
            valid_selection=true
            for idx in "${selected_indices[@]}"; do
                idx=$(echo "$idx" | tr -d ' ')
                if ! [[ "$idx" =~ ^[0-9]+$ ]] || [[ "$idx" -lt 1 ]] || [[ "$idx" -gt "${#v2ray_users[@]}" ]]; then
                    valid_selection=false
                    break
                fi
            done
            
            if [[ "$valid_selection" == false ]] || [[ ${#selected_indices[@]} -eq 0 ]]; then
                echo -e "${RED}Error: Selección inválida.${NC}"
                read -p "ENTER para continuar..."
                continue
            fi

            echo
            echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${CYAN}║ Seleccione la unidad de tiempo:                              ║${NC}"
            echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
            echo -e "${CYAN}║ [1] Minutos                                                  ║${NC}"
            echo -e "${CYAN}║ [2] Horas                                                    ║${NC}"
            echo -e "${CYAN}║ [3] Días                                                     ║${NC}"
            echo -e "${CYAN}║ [4] Meses (30 días)                                          ║${NC}"
           
            read -p "Opción: " unit_opt

            case $unit_opt in
                1) unit_str="minutes" ;;
                2) unit_str="hours" ;;
                3) unit_str="days" ;;
                4) unit_str="months" ;;
                *) 
                    echo -e "${RED}Opción inválida.${NC}"
                    read -p "ENTER para continuar..."
                    continue 
                    ;;
            esac

            read -p "Cantidad: " time_qty
            validar_numero "$time_qty" || { read -p "ENTER para continuar..."; continue; }

            for idx in "${selected_indices[@]}"; do
                idx=$(echo "$idx" | tr -d ' ')
                username="${v2ray_users[$((idx-1))]}"
                
                now_epoch=$(date +%s)
                
                case $unit_str in
                    minutes) add_seconds=$((time_qty * 60)) ;;
                    hours)   add_seconds=$((time_qty * 3600)) ;;
                    days)    add_seconds=$((time_qty * 86400)) ;;
                    months)  
                        new_exp_datetime=$(date -d "+$time_qty months" "+%Y-%m-%d %H:%M:%S")
                        new_exp_epoch=$(date -d "$new_exp_datetime" +%s)
                        ;;
                esac

                if [[ "$unit_str" != "months" ]]; then
                    new_exp_epoch=$((now_epoch + add_seconds))
                    new_exp_datetime=$(date -d "@$new_exp_epoch" "+%Y-%m-%d %H:%M:%S")
                fi

                if [[ -f "$V2RAY_DB" ]]; then
                    temp_file=$(mktemp)
                    while IFS=: read -r v_user v_uuid v_proto v_exp v_date v_traffic; do
                        if [[ "$v_user" == "$username" ]]; then
                            echo "${v_user}:${v_uuid}:${v_proto}:${new_exp_epoch}:${new_exp_datetime}:${v_traffic}" >> "$temp_file"
                        else
                            echo "${v_user}:${v_uuid}:${v_proto}:${v_exp}:${v_date}:${v_traffic}" >> "$temp_file"
                        fi
                    done < "$V2RAY_DB"
                    mv "$temp_file" "$V2RAY_DB"
                fi

                echo -e "${GREEN}✅ Usuario V2Ray '$username' renovado exitosamente.${NC}"
                echo "   Nueva expiración: $new_exp_datetime"
            done

            echo
            echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${CYAN}║ Renovación completada para los usuarios seleccionados. ✅    ║${NC}"
            echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
            echo
            read -p "ENTER para continuar..."
            ;;

        10)
            clear
            show_header
            echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${CYAN}║ Eliminar Usuario V2Ray                                       ║${NC}"
            echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
            echo
            
            if [[ ! -s "$V2RAY_DB" ]]; then
                echo -e "${RED}No hay usuarios V2Ray registrados.${NC}"
                read -p "ENTER para continuar..."
                continue
            fi

            echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
            printf "${CYAN} %-5s %-15s %-15s %-24s %-10s ${NC}\n" "N°" "Usuario" "Protocolo" "Expiración" "Estado"
            echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
            
            i=1
            declare -a v2ray_users=()
            while IFS=: read -r v_user v_uuid v_proto v_exp v_date v_traffic; do
                v2ray_users+=("$v_user")
                now_epoch=$(date +%s)
                if [[ "$v_exp" -le "$now_epoch" ]]; then
                    status="${RED}Expirado${NC}"
                else
                    status="${GREEN}Activo${NC}"
                fi
                printf "${CYAN} %-5s %-15s %-15s %-24s %-10b ${NC}\n" "$i" "$v_user" "$v_proto" "$v_date" "$status"
                ((i++))
            done < "$V2RAY_DB"
            echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
            echo
            
            read -p "Ingrese el/los número(s) de usuario a eliminar (ej: 1 o 1,2,3): " selection
            IFS=',' read -ra selected_indices <<< "$selection"
            
            valid_selection=true
            for idx in "${selected_indices[@]}"; do
                idx=$(echo "$idx" | tr -d ' ')
                if ! [[ "$idx" =~ ^[0-9]+$ ]] || [[ "$idx" -lt 1 ]] || [[ "$idx" -gt "${#v2ray_users[@]}" ]]; then
                    valid_selection=false
                    break
                fi
            done
            
            if [[ "$valid_selection" == false ]] || [[ ${#selected_indices[@]} -eq 0 ]]; then
                echo -e "${RED}Error: Selección inválida.${NC}"
                read -p "ENTER para continuar..."
                continue
            fi
            
            echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
            read -p " ¿Está seguro de eliminar los usuarios seleccionados? (s/N): " confirm
            echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
            
            if [[ "$confirm" =~ ^[Ss]$ ]]; then
                for idx in "${selected_indices[@]}"; do
                    idx=$(echo "$idx" | tr -d ' ')
                    username="${v2ray_users[$((idx-1))]}"
                    
                    if [[ -f "$V2RAY_DB" ]]; then
                        temp_file=$(mktemp)
                        grep -v "^${username}:" "$V2RAY_DB" > "$temp_file" 2>/dev/null || true
                        mv "$temp_file" "$V2RAY_DB"
                    fi
                    echo -e "${GREEN}✅ Usuario V2Ray '$username' eliminado correctamente.${NC}"
                done
            else
                echo -e "${YELLOW}Operación cancelada.${NC}"
            fi
            echo
            read -p "ENTER para continuar..."
            ;;

        11)
            clear
            show_header
            echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${CYAN}║ Lista de Usuarios V2Ray                                      ║${NC}"
            echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
            echo
            
            if [[ ! -s "$V2RAY_DB" ]]; then
                echo -e "${RED}No hay usuarios V2Ray registrados.${NC}"
                read -p "ENTER para continuar..."
                continue
            fi

            echo -e "${CYAN}┌────────────────────────────────────────────────────────────────────────┐${NC}"
            printf "%-15s %-15s %-15s %-12s\n" "Usuario" "Protocolo" "Tiempo" "Estado"
            echo -e "${CYAN}├────────────────────────────────────────────────────────────────────────┤${NC}"
            
            while IFS=: read -r v_user v_uuid v_proto v_exp v_date v_traffic; do
                now_epoch=$(date +%s)
                if [[ "$v_exp" -le "$now_epoch" ]]; then
                    time_left="${RED}Expirado${NC}"
                    status="offline"
                else
                    status="online"
                    diff=$((v_exp - now_epoch))
                    if [[ $diff -ge 2592000 ]]; then
                        months=$((diff / 2592000))
                        time_left="${months}ms"
                    elif [[ $diff -ge 86400 ]]; then
                        days=$((diff / 86400))
                        time_left="${days}d"
                    elif [[ $diff -ge 3600 ]]; then
                        hours=$((diff / 3600))
                        time_left="${hours}h"
                    elif [[ $diff -ge 60 ]]; then
                        minutes=$((diff / 60))
                        time_left="${minutes}mt"
                    else
                        time_left="${diff}sg"
                    fi
                fi

                printf "%-15s %-15s %-15b %-12s\n" "$v_user" "$v_proto" "$time_left" "$status"
            done < "$V2RAY_DB"

            echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
            echo
            read -p "ENTER para continuar..."
            ;;

        12)
            clear
            show_header
            echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${CYAN}║ Usuarios Online V2Ray                                        ║${NC}"
            echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
            echo
            
            if [[ ! -s "$V2RAY_DB" ]]; then
                echo -e "${RED}No hay usuarios V2Ray registrados.${NC}"
            else
                echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
                printf "${CYAN} %-20s %-15s %-15s ${NC}\n" "Usuario" "Protocolo" "Dispositivos"
                echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
                while IFS=: read -r v_user v_uuid v_proto v_exp v_date v_traffic; do
                    printf "${CYAN} %-20s %-15s %-15s ${NC}\n" "$v_user" "$v_proto" "N/A"
                done < "$V2RAY_DB"
                echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
            fi
            echo
            read -p "ENTER para continuar..."
            ;;

        0)
            break
            ;;

        *)
            echo
            echo -e "${RED}Opción inválida. Por favor, seleccione una opción del menú.${NC}"
            sleep 1.5
            ;;
    esac
done
