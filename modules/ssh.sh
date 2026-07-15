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
touch "$DB_FILE"

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

while true; do
    clear
    show_header
    echo -e "${CYAN}[1]${NC} Crear Usuario SSH"
    echo -e "${CYAN}[2]${NC} Eliminar Usuario SSH"
    echo -e "${CYAN}[3]${NC} Renovar Usuario SSH"
    echo -e "${CYAN}[4]${NC} Cambiar Contraseña"
    echo -e "${CYAN}[5]${NC} Usuarios Online"
    echo -e "${CYAN}[6]${NC} Lista de Usuarios"
    echo -e "${CYAN}[7]${NC} Eliminar Expirados"
    echo
    echo -e "${RED}[0]${NC} Regresar"
    echo
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo

    read -p "Seleccione una opción: " opt

    case $opt in
        1)
            clear
            show_header
            echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${CYAN}${NC} Crear Usuario SSH                                         ${CYAN}${NC}"
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
            echo -e "${CYAN}${NC} Seleccione la unidad de tiempo:                            ${CYAN}${NC}"
            echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
            echo -e "${CYAN}${NC} [1] Minutos                                                ${CYAN}${NC}"
            echo -e "${CYAN}${NC} [2] Horas                                                  ${CYAN}${NC}"
            echo -e "${CYAN}${NC} [3] Días                                                   ${CYAN}${NC}"
            echo -e "${CYAN}${NC} [4] Meses (30 días)                                        ${CYAN}${NC}"
            
            
            read -p "Opción: " unit_opt
            
            case $unit_opt in
                1) unit_str="minutes" ;;
                2) unit_str="hours" ;;
                3) unit_str="days" ;;
                4) unit_str="days"; time_qty=$((time_qty * 30)) ;;
                *) 
                    echo -e "${RED}Opción inválida.${NC}"
                    read -p "ENTER para continuar..."
                    continue 
                    ;;
            esac

            read -p "Cantidad: " time_qty
            validar_numero "$time_qty" || { read -p "ENTER para continuar..."; continue; }

            read -p "Número máximo de dispositivos: " max_devices
            
            # Validar solo que sea un número entero positivo (sin límite máximo)
            if [[ ! "$max_devices" =~ ^[0-9]+$ ]] || [[ "$max_devices" -le 0 ]]; then
                echo -e "${RED}Error: El número de dispositivos debe ser un número entero mayor a 0.${NC}"
                read -p "ENTER para continuar..."
                continue
            fi

            # Calcular fechas de expiración
            exp_datetime=$(date -d "+$time_qty $unit_str" "+%Y-%m-%d %H:%M:%S")
            exp_date=$(date -d "+$time_qty $unit_str" +%Y-%m-%d)
            exp_epoch=$(date -d "+$time_qty $unit_str" +%s)

            # Crear usuario con el shell personalizado para limitar conexiones
            useradd -M -s "$SHELL_SCRIPT" -e "$exp_date" "$username" 2>/dev/null
            if [[ $? -ne 0 ]]; then
                echo -e "${RED}Error al crear el usuario. Verifique que no exista.${NC}"
                read -p "ENTER para continuar..."
                continue
            fi
            
            echo "$username:$password" | chpasswd

            # Eliminar entrada anterior si existe y agregar nueva
            if [[ -f "$DB_FILE" ]]; then
                temp_file=$(mktemp)
                grep -v "^${username}:" "$DB_FILE" > "$temp_file" 2>/dev/null || true
                mv "$temp_file" "$DB_FILE"
            fi
            
            # Agregar a la base de datos con el formato correcto
            echo "${username}:${exp_epoch}:${exp_datetime}:${max_devices}" >> "$DB_FILE"

            # Obtener puertos configurados
            obtener_puertos

            echo
            echo
            echo -e         "───────────────────────────────────────────────────────────────"
            echo -e "${GREEN}✅ Usuario creado exitosamente.${NC}"
            echo -e "${CYAN}${NC}                                                           ${CYAN}${NC}"
            echo -e "${CYAN}${NC} Dominio: $DOMAIN                                          ${CYAN}${NC}"
            echo -e "${CYAN}${NC} Usuario: $username                                         ${CYAN}${NC}"
            echo -e "${CYAN}${NC} Contraseña: $password                                      ${CYAN}${NC}"
            echo -e "${CYAN}${NC} Dispositivos máx: $max_devices                             ${CYAN}${NC}"
            echo -e         "───────────────────────────────────────────────────────────────"
            echo -e "${CYAN}${NC} SSL: $SSL_PORT                                            ${CYAN}${NC}"
            echo -e "${CYAN}${NC} DROPBEAR: $DROPBEAR_PORT                                  ${CYAN}${NC}"
            echo -e "${CYAN}${NC} UDP: $UDP_PORT                                            ${CYAN}${NC}"
            echo -e "${CYAN}${NC} OpenSSH: $OPENSSH_PORT                                    ${CYAN}${NC}"
            echo -e "${CYAN}${NC} WebSocket: $WEBSOCKET_PORT                                ${CYAN}${NC}"
            echo -e "${CYAN}${NC} V2Ray: $V2RAY_PORT                                        ${CYAN}${NC}"
            echo -e "${CYAN}${NC}                                                           ${CYAN}${NC}"
            echo -e         "───────────────────────────────────────────────────────────────"
            echo
            
            echo -e "${CYAN}${NC} Expira el: $exp_datetime                                  ${CYAN}${NC}"
            
            echo
            read -p "ENTER para continuar..."
            ;;

        2)
            clear
            show_header
            echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${CYAN}${NC} Eliminar Usuario SSH                                       ${CYAN}${NC}"
            echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
            echo
            
            users_list=$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd)
            
            if [[ -z "$users_list" ]]; then
                echo -e "${RED}No hay usuarios registrados en el sistema.${NC}"
                read -p "ENTER para continuar..."
                continue
            fi

            echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
            printf "${CYAN}${NC} %-5s %-15s %-24s %-26s ${CYAN}${NC}\n" "N°" "Usuario" "Expiración" "Estado"
            echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
            
            i=1
            declare -a user_array
            for user in $users_list; do
                user_array+=("$user")
                db_entry=$(grep "^${user}:" "$DB_FILE" 2>/dev/null | head -1)
                if [[ -n "$db_entry" ]]; then
                    if [[ "$db_entry" == *:*:*:* ]]; then
                        exp_info=$(echo "$db_entry" | awk -F: '{print $3":"$4":"$5}')
                    else
                        exp_info=$(echo "$db_entry" | cut -d':' -f3-)
                    fi
                    exp_epoch=$(echo "$db_entry" | cut -d':' -f2)
                else
                    exp_info=$(chage -l "$user" | grep "Account expires" | cut -d: -f2 | xargs)
                    if [[ "$exp_info" != "never" ]]; then
                        exp_epoch=$(date -d "$exp_info" +%s 2>/dev/null)
                    else
                        exp_epoch=9999999999
                    fi
                fi
                
                now_epoch=$(date +%s)
                if [[ "$exp_info" == "never" ]]; then
                    status="${GREEN}Activo (Sin exp.)${NC}"
                    exp_info="Nunca"
                elif [[ $exp_epoch -lt $now_epoch ]]; then
                    status="${RED}Expirado${NC}"
                else
                    status="${GREEN}Activo${NC}"
                fi
                
                printf "${CYAN} ${NC} %-5s %-15s %-24s %-26b ${CYAN} ${NC}\n" "$i" "$user" "$exp_info" "$status"
                ((i++))
            done
            echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
            echo
            
            read -p "Ingrese el/los número(s) de usuario a eliminar (ej: 1 o 1,2,3): " selection
            
            # Parse selection
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
                    # Eliminar de la base de datos
                    if [[ -f "$DB_FILE" ]]; then
                        temp_file=$(mktemp)
                        grep -v "^${username}:" "$DB_FILE" > "$temp_file" 2>/dev/null || true
                        mv "$temp_file" "$DB_FILE"
                    fi
                    echo -e "${GREEN}✅ Usuario '$username' eliminado correctamente.${NC}"
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
            echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
            echo -e "${CYAN} ${NC} Renovar Usuario SSH                                        ${CYAN} ${NC}"
            echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
            echo
            
            users_list=$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd)
            
            if [[ -z "$users_list" ]]; then
                echo -e "${RED}No hay usuarios registrados en el sistema.${NC}"
                read -p "ENTER para continuar..."
                continue
            fi

            echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
            printf "${CYAN}${NC} %-5s %-15s %-24s %-26s ${CYAN} ${NC}\n" "N°" "Usuario" "Expiración" "Estado"
            echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
            
            i=1
            declare -a user_array
            for user in $users_list; do
                user_array+=("$user")
                db_entry=$(grep "^${user}:" "$DB_FILE" 2>/dev/null | head -1)
                if [[ -n "$db_entry" ]]; then
                    if [[ "$db_entry" == *:*:*:* ]]; then
                        exp_info=$(echo "$db_entry" | awk -F: '{print $3":"$4":"$5}')
                    else
                        exp_info=$(echo "$db_entry" | cut -d':' -f3-)
                    fi
                    exp_epoch=$(echo "$db_entry" | cut -d':' -f2)
                else
                    exp_info=$(chage -l "$user" | grep "Account expires" | cut -d: -f2 | xargs)
                    if [[ "$exp_info" != "never" ]]; then
                        exp_epoch=$(date -d "$exp_info" +%s 2>/dev/null)
                    else
                        exp_epoch=9999999999
                    fi
                fi
                
                now_epoch=$(date +%s)
                if [[ "$exp_info" == "never" ]]; then
                    status="${GREEN}Activo (Sin exp.)${NC}"
                    exp_info="Nunca"
                elif [[ $exp_epoch -lt $now_epoch ]]; then
                    status="${RED}Expirado${NC}"
                else
                    status="${GREEN}Activo${NC}"
                fi
                
                printf "${CYAN} ${NC} %-5s %-15s %-24s %-26b ${CYAN} ${NC}\n" "$i" "$user" "$exp_info" "$status"
                ((i++))
            done
            echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
            echo
            
            read -p "Ingrese el/los número(s) de usuario a renovar (ej: 1 o 1,2,3): " selection
            
            # Parse selection
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
            echo -e "${CYAN}${NC} Seleccione la unidad de tiempo:                            ${CYAN}${NC}"
            echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
            echo -e "${CYAN}${NC} [1] Minutos                                                ${CYAN}${NC}"
            echo -e "${CYAN}${NC} [2] Horas                                                  ${CYAN}${NC}"
            echo -e "${CYAN}${NC} [3] Días                                                   ${CYAN}${NC}"
            echo -e "${CYAN}${NC} [4] Meses (30 días)                                        ${CYAN}${NC}"
           
            
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
            
            # Validar solo que sea un número entero positivo (sin límite máximo)
            if [[ ! "$max_devices_input" =~ ^[0-9]+$ ]] || [[ "$max_devices_input" -le 0 ]]; then
                echo -e "${RED}Error: El número de dispositivos debe ser un número entero mayor a 0.${NC}"
                read -p "ENTER para continuar..."
                continue
            fi

            # Loop through selected users and renew them
            for idx in "${selected_indices[@]}"; do
                idx=$(echo "$idx" | tr -d ' ')
                username="${user_array[$((idx-1))]}"
                
                # Calcular nueva fecha de expiración desde el momento actual (reemplaza el tiempo anterior)
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
                
                # Actualizar DB manteniendo el nuevo límite de dispositivos
                if [[ -f "$DB_FILE" ]]; then
                    temp_file=$(mktemp)
                    grep -v "^${username}:" "$DB_FILE" > "$temp_file" 2>/dev/null || true
                    echo "${username}:${new_exp_epoch}:${new_exp_datetime}:${max_devices_input}" >> "$temp_file"
                    mv "$temp_file" "$DB_FILE"
                fi

                echo -e "${GREEN}✅ Usuario '$username' renovado exitosamente.${NC}"
                echo "   Nueva expiración: $new_exp_datetime"
            done

            echo
            echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${CYAN}${NC} Renovación completada para los usuarios seleccionados. ✅  ${CYAN}${NC}"
            echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
            echo
            read -p "ENTER para continuar..."
            ;;

        4)
            clear
            show_header
            echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${CYAN}${NC} Cambiar Contraseña                                         ${CYAN}${NC}"
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
            echo -e "${CYAN}══════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${CYAN}${NC} Usuarios Online                                            ${CYAN}${NC}"
            echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
            echo
            
            online_users=$(who | awk '{print $1}' | sort -u)
            
            if [[ -z "$online_users" ]]; then
                echo -e "${RED}No hay usuarios conectados en este momento.${NC}"
            else
                echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
                printf "${CYAN} ${NC} %-11s %-9s %-17s %s %s ${CYAN} ${NC}\n" "Usuario" "Terminal" "IP/Puerto" "Fecha" "Hora"
                echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
                who | awk '{printf "${CYAN} ${NC} %-11s %-9s %-17s %s %s ${CYAN} ${NC}\n", $1, $2, $5, $3, $4}'
                echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
            fi
            echo
            read -p "ENTER para continuar..."
            ;;

        6)
            clear
            show_header
            
            echo -e "${CYAN}${NC} Lista de Usuarios                                          ${CYAN}${NC}"
            
            echo
            
            users_list=$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd)
            
            if [[ -z "$users_list" ]]; then
                echo -e "${RED}No hay usuarios registrados en el sistema.${NC}"
                echo
                read -p "ENTER para continuar..."
            else
                echo -e "${CYAN}┌────────────────────────────────────────────────────────────────────────┐${NC}"
                printf "%-15s %-15s %-12s %-12s %-15s\n" \
                "Usuario" "Tiempo" "Estado" "Conexión" "Dispositivos"
                echo -e "${CYAN}├────────────────────────────────────────────────────────────────────────┤${NC}"
                
                for user in $users_list; do
                    exp_info=""
                    db_entry=$(grep "^${user}:" "$DB_FILE" 2>/dev/null | head -1)

                    if [[ -n "$db_entry" ]]; then
                        exp_epoch=$(echo "$db_entry" | cut -d':' -f2)
                        exp_datetime=$(echo "$db_entry" | cut -d':' -f3-)

                        max_dev=$(echo "$db_entry" | awk -F: '{print $NF}')

                        if [[ "$db_entry" != *:*:*:* ]]; then
                            max_dev=1
                        fi
                    else
                        exp_info=$(chage -l "$user" | grep "Account expires" | cut -d: -f2 | xargs)

                        if [[ "$exp_info" != "never" ]]; then
                            exp_epoch=$(date -d "$exp_info" +%s 2>/dev/null)
                            exp_datetime="$exp_info"
                        else
                            exp_epoch=9999999999
                            exp_datetime="Nunca"
                        fi

                        max_dev=1
                    fi

                    if [[ -z "$max_dev" ]] || [[ "$max_dev" -le 0 ]]; then
                        max_dev=1
                    fi

                    current_dev=$(who | grep "^${user} " | wc -l)

                    now_epoch=$(date +%s)

                    if [[ "$exp_datetime" == "Nunca" ]]; then
                        status="${GREEN}Activo${NC}"
                        time_left="Nunca"

                    elif [[ $exp_epoch -le $now_epoch ]]; then
                        time_left="${RED}Expirado${NC}"
                        status="${GRAY}Offline${NC}"

                    else
                        status="${GREEN}Activo${NC}"

                        diff=$((exp_epoch - now_epoch))

                        # Lógica simplificada para mostrar solo la unidad de tiempo mayor
                        if [[ $diff -ge 86400 ]]; then
                            days=$((diff / 86400))
                            [[ $days -eq 1 ]] && time_left="${days} DIA" || time_left="${days} DIAS"
                        elif [[ $diff -ge 3600 ]]; then
                            hours=$((diff / 3600))
                            [[ $hours -eq 1 ]] && time_left="${hours} HORA" || time_left="${hours} HORAS"
                        elif [[ $diff -ge 60 ]]; then
                            minutes=$((diff / 60))
                            [[ $minutes -eq 1 ]] && time_left="${minutes} MINUTO" || time_left="${minutes} MINUTOS"
                        else
                            [[ $diff -eq 1 ]] && time_left="${diff} SEGUNDO" || time_left="${diff} SEGUNDOS"
                        fi
                    fi

                    if who | grep -q "^${user} "; then
                        connection="${GREEN}Online${NC}"
                    else
                        connection="${GRAY}Offline${NC}"
                    fi

                    printf "%-15s %-15s %-12s %-12s %-15s\n" \
                    "$user" \
                    "$(echo -e "$time_left" | sed 's/\x1b\[[0-9;]*m//g')" \
                    "$(echo -e "$status" | sed 's/\x1b\[[0-9;]*m//g')" \
                    "$(echo -e "$connection" | sed 's/\x1b\[[0-9;]*m//g')" \
                    "${current_dev}/${max_dev}"

                echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
                echo
                read -p "ENTER para continuar..."
            fi
            ;;

        7)
            clear
            show_header
            echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${CYAN}${NC} Eliminar Usuarios Expirados                                ${CYAN}${NC}"
            echo -e "${CYAN}══════════════════════════════════════════════════════════════╝${NC}"
            echo
            
            deleted_count=0
            current_epoch=$(date +%s)
            
            if [[ -f "$DB_FILE" ]]; then
                while IFS=':' read -r db_user db_epoch db_datetime db_max; do
                    if [[ -n "$db_user" ]]; then
                        if [[ "$db_epoch" -lt "$current_epoch" ]]; then
                            if id "$db_user" &>/dev/null; then
                                userdel "$db_user" 2>/dev/null
                                echo -e "${RED}️ Usuario '$db_user' eliminado (Expiró: $db_datetime)${NC}"
                                ((deleted_count++))
                            fi
                        fi
                    fi
                done < "$DB_FILE"
                
                # Limpiar la base de datos de usuarios expirados
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
                            echo -e "${RED}️ Usuario '$user' eliminado (Expiró: $exp_info)${NC}"
                            ((deleted_count++))
                        fi
                    fi
                fi
            done
            
            echo
            if [[ $deleted_count -eq 0 ]]; then
                echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
                echo -e "${CYAN}${NC} No se encontraron usuarios expirados.                     ${CYAN}${NC}"
                echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
            else
                
                echo -e "${CYAN}${NC} Se eliminaron $deleted_count usuario(s) expirado(s).                  ${CYAN}${NC}"
                
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
