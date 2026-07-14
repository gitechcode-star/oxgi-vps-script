#!/bin/bash

# Cargar módulos de interfaz
source /usr/local/oxgi/modules/color.sh
source /usr/local/oxgi/modules/header.sh

# Definir cajas más anchas para acomodar la nueva columna (80 caracteres)
BOX_TOP="┌────────────────────────────────────────────────────────────────────────┐"
BOX_BOT="└────────────────────────────────────────────────────────────────────────┘"
BOX_LINE="────────────────────────────────────────────────────────────────────────"

# Archivo de base de datos local
mkdir -p /etc/oxgi
DB_FILE="/etc/oxgi/ssh_users.db"
touch "$DB_FILE"

# Crear script de shell personalizado para limitar conexiones
SHELL_SCRIPT="/usr/local/oxgi/bin/oxgi-ssh-shell"
mkdir -p /usr/local/oxgi/bin
if [ ! -f "$SHELL_SCRIPT" ]; then
    cat << 'EOF' > "$SHELL_SCRIPT"
#!/bin/bash
USER_NAME=$(whoami)
# Leer límite desde la base de datos (campo 4). Si no existe, default 1.
MAX=$(grep "^$USER_NAME:" /etc/oxgi/ssh_users.db 2>/dev/null | cut -d: -f4)
if [ -z "$MAX" ]; then MAX=1; fi

# Contar sesiones sshd activas para este usuario
CURRENT=$(ps -u $USER_NAME -o pid,cmd 2>/dev/null | grep "sshd: $USER_NAME" | grep -v grep | wc -l)

if [ "$CURRENT" -gt "$MAX" ]; then
    echo -e "\e[31mLimite de $MAX dispositivos alcanzado. Conexion rechazada.\e[0m"
    sleep 3
    exit 1
fi

# Mantener conexión viva para túneles/proxy
while true; do sleep 3600; done
EOF
    chmod +x "$SHELL_SCRIPT"
    # Agregar a shells permitidos si no está
    if ! grep -q "$SHELL_SCRIPT" /etc/shells; then
        echo "$SHELL_SCRIPT" >> /etc/shells
    fi
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

# Función auxiliar para validar números enteros positivos
validar_numero() {
    if [[ ! "$1" =~ ^[0-9]+$ ]] || [[ "$1" -le 0 ]]; then
        echo -e "${RED}Error: Debe ingresar un número entero válido mayor a 0.${NC}"
        return 1
    fi
    return 0
}

while true; do
    clear
    show_header
    echo -e "${GREEN}SSH MANAGER${NC}"
    echo
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
    echo -e "${BLUE}══════════════════════════════════════════════════════════════════════════════${NC}"
    echo

    read -p "Seleccione una opción: " opt

    case $opt in
        1)
            clear
            show_header
            echo "$BOX_TOP"
            echo " Crear Usuario SSH"
            echo "$BOX_BOT"
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
            echo "$BOX_TOP"
            echo " Seleccione la unidad de tiempo:"
            echo "$BOX_BOT"
            echo "$BOX_TOP"
            echo "  [1] Minutos"
            echo "  [2] Horas"
            echo "  [3] Días"
            echo "  [4] Meses"
            echo "$BOX_BOT"
            
            echo "$BOX_TOP"
            read -p "├─ Opción: " unit_opt
            echo "$BOX_BOT"
            
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

            echo "$BOX_TOP"
            read -p "├─ Cantidad: " time_qty
            echo "$BOX_BOT"
            validar_numero "$time_qty" || { read -p "ENTER para continuar..."; continue; }

            echo "$BOX_TOP"
            read -p "├─ Número máximo de dispositivos: " max_devices
            echo "$BOX_BOT"
            validar_numero "$max_devices" || { read -p "ENTER para continuar..."; continue; }

            # Calcular fechas de expiración
            exp_datetime=$(date -d "+$time_qty $unit_str" "+%Y-%m-%d %H:%M:%S")
            exp_date=$(date -d "+$time_qty $unit_str" +%Y-%m-%d)
            exp_epoch=$(date -d "+$time_qty $unit_str" +%s)

            # Crear usuario con el shell personalizado para limitar conexiones
            useradd -M -s "$SHELL_SCRIPT" -e "$exp_date" "$username"
            echo "$username:$password" | chpasswd

            # Guardar en base de datos local (Formato: user:epoch:datetime:max_devices)
            sed -i "/^$username:/d" "$DB_FILE" 2>/dev/null
            echo "$username:$exp_epoch:$exp_datetime:$max_devices" >> "$DB_FILE"

            # Obtener dominio configurado
            DOMAIN="No disponible"
            if [[ -f /etc/oxgi/config.conf ]]; then
                source /etc/oxgi/config.conf 2>/dev/null
                [[ -n "$DOMAIN" && "$DOMAIN" != "No disponible" ]] && DOMAIN="$DOMAIN"
                [[ -n "$DOMINIO" ]] && DOMAIN="$DOMINIO"
                [[ -n "$HOST" ]] && DOMAIN="$HOST"
            fi

            echo
            echo -e "${GREEN}✅ Usuario creado exitosamente.${NC}"
            echo
            echo "$BOX_TOP"
            echo ""
            echo "├─ Dominio: $DOMAIN"
            echo "├─ Usuario: $username"
            echo "├─ Contraseña: $password"
            echo "├─ Dispositivos máx: $max_devices"
            echo ""
            echo "$BOX_BOT"
            echo
            echo "$BOX_TOP"
            echo " Expira el: $exp_datetime"
            echo "$BOX_BOT"
            echo
            read -p "ENTER para continuar..."
            ;;

        2)
            clear
            show_header
            echo "$BOX_TOP"
            echo " Eliminar Usuario SSH"
            echo "$BOX_BOT"
            echo
            
            read -p "Nombre de usuario a eliminar: " username
            validar_usuario "$username" || { read -p "ENTER para continuar..."; continue; }
            
            if ! id "$username" &>/dev/null; then
                echo -e "${RED}Error: El usuario '$username' no existe.${NC}"
                read -p "ENTER para continuar..."
                continue
            fi

            echo "$BOX_TOP"
            read -p "├─ ¿Está seguro de eliminar a '$username'? (s/N): " confirm
            echo "$BOX_BOT"
            
            if [[ "$confirm" =~ ^[Ss]$ ]]; then
                userdel "$username" 2>/dev/null
                sed -i "/^$username:/d" "$DB_FILE" 2>/dev/null
                echo
                echo -e "${GREEN}✅ Usuario '$username' eliminado correctamente.${NC}"
            else
                echo -e "${YELLOW}Operación cancelada.${NC}"
            fi
            echo
            read -p "ENTER para continuar..."
            ;;

        3)
            clear
            show_header
            echo "$BOX_TOP"
            echo " Renovar Usuario SSH"
            echo "$BOX_BOT"
            echo
            
            read -p "Nombre de usuario a renovar: " username
            validar_usuario "$username" || { read -p "ENTER para continuar..."; continue; }
            
            if ! id "$username" &>/dev/null; then
                echo -e "${RED}Error: El usuario '$username' no existe.${NC}"
                read -p "ENTER para continuar..."
                continue
            fi

            echo
            echo "$BOX_TOP"
            echo " Seleccione la unidad de tiempo a agregar:"
            echo "$BOX_BOT"
            echo "$BOX_TOP"
            echo "  [1] Minutos"
            echo "  [2] Horas"
            echo "  [3] Días"
            echo "  [4] Meses"
            echo "$BOX_BOT"
            
            echo "$BOX_TOP"
            read -p "├─ Opción: " unit_opt
            echo "$BOX_BOT"

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

            echo "$BOX_TOP"
            read -p "├─ Cantidad a agregar: " time_qty
            echo "$BOX_BOT"
            validar_numero "$time_qty" || { read -p "ENTER para continuar..."; continue; }

            # Obtener fecha actual de expiración y límite de dispositivos
            db_entry=$(grep "^$username:" "$DB_FILE" 2>/dev/null)
            max_dev=$(echo "$db_entry" | cut -d: -f4)
            if [ -z "$max_dev" ]; then max_dev=1; fi

            if [[ -n "$db_entry" ]]; then
                current_date_str=$(echo "$db_entry" | cut -d: -f3)
                new_exp_datetime=$(date -d "$current_date_str + $time_qty $unit_str" "+%Y-%m-%d %H:%M:%S" 2>/dev/null)
            else
                new_exp_datetime=$(date -d "+$time_qty $unit_str" "+%Y-%m-%d %H:%M:%S")
            fi

            new_exp_date=$(echo "$new_exp_datetime" | cut -d' ' -f1)
            new_exp_epoch=$(date -d "$new_exp_datetime" +%s)

            usermod -e "$new_exp_date" "$username"
            
            # Actualizar DB manteniendo el límite de dispositivos
            sed -i "/^$username:/d" "$DB_FILE" 2>/dev/null
            echo "$username:$new_exp_epoch:$new_exp_datetime:$max_dev" >> "$DB_FILE"

            echo
            echo -e "${GREEN}✅ Usuario '$username' renovado exitosamente.${NC}"
            echo
            echo "$BOX_TOP"
            echo " Nueva expiración: $new_exp_datetime"
            echo "$BOX_BOT"
            echo
            read -p "ENTER para continuar..."
            ;;

        4)
            clear
            show_header
            echo "$BOX_TOP"
            echo " Cambiar Contraseña"
            echo "$BOX_BOT"
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
            echo "$BOX_TOP"
            echo " Usuarios Online"
            echo "$BOX_BOT"
            echo
            
            online_users=$(who | awk '{print $1}' | sort -u)
            
            if [[ -z "$online_users" ]]; then
                echo -e "${RED}No hay usuarios conectados en este momento.${NC}"
            else
                echo "$BOX_TOP"
                printf " %-11s %-9s %-17s %s %s\n" "Usuario" "Terminal" "IP/Puerto" "Fecha" "Hora"
                echo "$BOX_LINE"
                who | awk '{printf " %-11s %-9s %-17s %s %s\n", $1, $2, $5, $3, $4}'
                echo "$BOX_BOT"
            fi
            echo
            read -p "ENTER para continuar..."
            ;;

        6)
            clear
            show_header
            echo "$BOX_TOP"
            echo " Lista de Usuarios"
            echo "$BOX_BOT"
            echo
            
            users_list=$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd)
            
            if [[ -z "$users_list" ]]; then
                echo -e "${RED}No hay usuarios registrados en el sistema.${NC}"
            else
                echo "$BOX_TOP"
                printf " %-12s %-24s %-18s %-14s %s\n" "Usuario" "Expiración Precisa" "Estado" "Conexión" "dispositivos"
                echo "$BOX_LINE"
                for user in $users_list; do
                    db_entry=$(grep "^$user:" "$DB_FILE" 2>/dev/null)
                    if [[ -n "$db_entry" ]]; then
                        exp_info=$(echo "$db_entry" | cut -d: -f3)
                        exp_epoch=$(echo "$db_entry" | cut -d: -f2)
                        max_dev=$(echo "$db_entry" | cut -d: -f4)
                    else
                        exp_info=$(chage -l "$user" | grep "Account expires" | cut -d: -f2 | xargs)
                        if [[ "$exp_info" != "never" ]]; then
                            exp_epoch=$(date -d "$exp_info" +%s 2>/dev/null)
                        else
                            exp_epoch=9999999999
                        fi
                        max_dev=1
                    fi
                    
                    # Si el campo max_dev está vacío (por bases de datos antiguas), default a 1
                    if [[ -z "$max_dev" ]]; then max_dev=1; fi

                    # Contar dispositivos conectados actualmente
                    current_dev=$(ps -u "$user" -o pid,cmd 2>/dev/null | grep "sshd: $user" | grep -v grep | wc -l)
                    
                    now_epoch=$(date +%s)
                    if [[ "$exp_info" == "never" ]]; then
                        status="${GREEN}Activo (Sin exp.)${NC}"
                        exp_info="Nunca"
                    elif [[ $exp_epoch -lt $now_epoch ]]; then
                        status="${RED}Expirado${NC}"
                    else
                        status="${GREEN}Activo${NC}"
                    fi
                    
                    if who | grep -q "^$user "; then
                        connection="${GREEN}Online${NC}"
                    else
                        connection="${GRAY}Offline${NC}"
                    fi
                    
                    # Imprimir fila con formato ajustado
                    printf " %-12s %-24s %-26b %-22b %s/%s\n" "$user" "$exp_info" "$status" "$connection" "$current_dev" "$max_dev"
                done
                echo "$BOX_BOT"
            fi
            echo
            read -p "ENTER para continuar..."
            ;;

        7)
            clear
            show_header
            echo "$BOX_TOP"
            echo " Eliminar Usuarios Expirados"
            echo "$BOX_BOT"
            echo
            
            deleted_count=0
            current_epoch=$(date +%s)
            
            if [[ -f "$DB_FILE" ]]; then
                while IFS=: read -r db_user db_epoch db_datetime db_max; do
                    if [[ -n "$db_user" ]]; then
                        if [[ "$db_epoch" -lt "$current_epoch" ]]; then
                            if id "$db_user" &>/dev/null; then
                                userdel "$db_user" 2>/dev/null
                                echo -e "${RED}🗑️ Usuario '$db_user' eliminado (Expiró: $db_datetime)${NC}"
                                ((deleted_count++))
                            fi
                            sed -i "/^$db_user:/d" "$DB_FILE"
                        fi
                    fi
                done < "$DB_FILE"
            fi

            users_list=$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd)
            for user in $users_list; do
                if ! grep -q "^$user:" "$DB_FILE" 2>/dev/null; then
                    exp_info=$(chage -l "$user" | grep "Account expires" | cut -d: -f2 | xargs)
                    if [[ "$exp_info" != "never" ]] && [[ -n "$exp_info" ]]; then
                        exp_epoch=$(date -d "$exp_info" +%s 2>/dev/null)
                        if [[ -n "$exp_epoch" ]] && [[ "$exp_epoch" -lt "$current_epoch" ]]; then
                            userdel "$user" 2>/dev/null
                            echo -e "${RED}🗑️ Usuario '$user' eliminado (Expiró: $exp_info)${NC}"
                            ((deleted_count++))
                        fi
                    fi
                fi
            done
            
            echo
            if [[ $deleted_count -eq 0 ]]; then
                echo "$BOX_TOP"
                echo " No se encontraron usuarios expirados."
                echo "$BOX_BOT"
            else
                echo "$BOX_TOP"
                echo " Se eliminaron $deleted_count usuario(s) expirado(s)."
                echo "$BOX_BOT"
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
