#!/bin/bash

# Cargar módulos de interfaz
source /usr/local/oxgi/modules/color.sh
source /usr/local/oxgi/modules/header.sh

# Función auxiliar para validar nombre de usuario (solo letras, números y guiones bajos)
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

# Función auxiliar para verificar si un usuario existe
usuario_existe() {
    if id "$1" &>/dev/null; then
        return 0
    else
        echo -e "${RED}Error: El usuario '$1' no existe.${NC}"
        return 1
    fi
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
    echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
    echo

    read -p "Seleccione una opción: " opt

    case $opt in
        1)
            clear
            show_header
            echo -e "${YELLOW}Crear Usuario SSH${NC}"
            echo
            
            read -p "Nombre de usuario: " username
            validar_usuario "$username" || { read -p "ENTER para continuar..."; continue; }
            
            if usuario_existe "$username"; then
                echo -e "${RED}Error: El usuario '$username' ya existe.${NC}"
                read -p "ENTER para continuar..."
                continue
            fi

            read -p "Contraseña (dejar en blanco para generar una aleatoria): " password
            if [[ -z "$password" ]]; then
                password=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9' | head -c 10)
                echo -e "${CYAN}Contraseña generada: ${GREEN}$password${NC}"
            fi

            read -p "Días de validez: " days
            validar_numero "$days" || { read -p "ENTER para continuar..."; continue; }

            # Calcular fecha de expiración
            exp_date=$(date -d "+$days days" +%Y-%m-%d)

            # Crear usuario sin directorio home y sin acceso a shell (ideal para túneles/proxy)
            useradd -M -s /bin/false -e "$exp_date" "$username"
            echo "$username:$password" | chpasswd

            echo
            echo -e "${GREEN}✅ Usuario '$username' creado exitosamente.${NC}"
            echo -e "${CYAN}├─ Contraseña: ${GREEN}$password${NC}"
            echo -e "${CYAN}└─ Expira el: ${GREEN}$exp_date${NC}"
            echo
            read -p "ENTER para continuar..."
            ;;

        2)
            clear
            show_header
            echo -e "${YELLOW}Eliminar Usuario SSH${NC}"
            echo
            
            read -p "Nombre de usuario a eliminar: " username
            validar_usuario "$username" || { read -p "ENTER para continuar..."; continue; }
            
            if usuario_existe "$username"; then
                read -p "¿Está seguro de eliminar a '$username'? (s/N): " confirm
                if [[ "$confirm" =~ ^[Ss]$ ]]; then
                    userdel "$username"
                    echo -e "${GREEN}✅ Usuario '$username' eliminado correctamente.${NC}"
                else
                    echo -e "${YELLOW}Operación cancelada.${NC}"
                fi
            fi
            echo
            read -p "ENTER para continuar..."
            ;;

        3)
            clear
            show_header
            echo -e "${YELLOW}Renovar Usuario SSH${NC}"
            echo
            
            read -p "Nombre de usuario a renovar: " username
            validar_usuario "$username" || { read -p "ENTER para continuar..."; continue; }
            
            if usuario_existe "$username"; then
                read -p "Días adicionales a renovar: " days
                validar_numero "$days" || { read -p "ENTER para continuar..."; continue; }

                # Obtener fecha actual de expiración
                current_exp=$(chage -l "$username" | grep "Account expires" | cut -d: -f2 | xargs)
                
                # Si la cuenta ya expiró o dice "never", usamos hoy como base. Si no, sumamos a la fecha actual.
                if [[ "$current_exp" == "never" ]] || [[ -z "$current_exp" ]]; then
                    new_exp=$(date -d "+$days days" +%Y-%m-%d)
                else
                    # Intentar sumar días a la fecha existente
                    new_exp=$(date -d "$current_exp + $days days" +%Y-%m-%d 2>/dev/null)
                    if [[ $? -ne 0 ]]; then
                        new_exp=$(date -d "+$days days" +%Y-%m-%d) # Fallback a hoy si falla el parseo
                    fi
                fi

                usermod -e "$new_exp" "$username"
                echo -e "${GREEN}✅ Usuario '$username' renovado hasta el: $new_exp${NC}"
            fi
            echo
            read -p "ENTER para continuar..."
            ;;

        4)
            clear
            show_header
            echo -e "${YELLOW}Cambiar Contraseña${NC}"
            echo
            
            read -p "Nombre de usuario: " username
            validar_usuario "$username" || { read -p "ENTER para continuar..."; continue; }
            
            if usuario_existe "$username"; then
                read -p "Nueva contraseña (dejar en blanco para generar una aleatoria): " new_password
                if [[ -z "$new_password" ]]; then
                    new_password=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9' | head -c 10)
                    echo -e "${CYAN}Contraseña generada: ${GREEN}$new_password${NC}"
                fi

                echo "$username:$new_password" | chpasswd
                echo -e "${GREEN}✅ Contraseña de '$username' actualizada correctamente.${NC}"
            fi
            echo
            read -p "ENTER para continuar..."
            ;;

        5)
            clear
            show_header
            echo -e "${YELLOW}Usuarios Online${NC}"
            echo
            
            # Obtener sesiones activas excluyendo la sesión actual del script si es local
            online_users=$(who | awk '{print $1, $2, $5, $3, $4}' | sort -u)
            
            if [[ -z "$online_users" ]]; then
                echo -e "${RED}No hay usuarios conectados en este momento.${NC}"
            else
                echo -e "${CYAN}Usuario     Terminal    IP/Puerto         Hora${NC}"
                echo -e "${BLUE}─────────────────────────────────────────────────────${NC}"
                who | awk '{printf "%-12s %-10s %-18s %s %s\n", $1, $2, $5, $3, $4}'
            fi
            echo
            read -p "ENTER para continuar..."
            ;;

        6)
            clear
            show_header
            echo -e "${YELLOW}Lista de Usuarios${NC}"
            echo
            
            # Listar usuarios con UID >= 1000 (usuarios normales, no del sistema)
            users_list=$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd)
            
            if [[ -z "$users_list" ]]; then
                echo -e "${RED}No hay usuarios registrados en el sistema.${NC}"
            else
                echo -e "${CYAN}Usuario     Expiración            Estado${NC}"
                echo -e "${BLUE}──────────────────────────────────────────────${NC}"
                for user in $users_list; do
                    exp_info=$(chage -l "$user" | grep "Account expires" | cut -d: -f2 | xargs)
                    
                    # Determinar estado
                    if [[ "$exp_info" == "never" ]]; then
                        status="${GREEN}Activo (Sin exp.)${NC}"
                    else
                        # Comparar fecha de expiración con hoy
                        exp_epoch=$(date -d "$exp_info" +%s 2>/dev/null)
                        now_epoch=$(date +%s)
                        if [[ $exp_epoch -lt $now_epoch ]]; then
                            status="${RED}Expirado${NC}"
                        else
                            status="${GREEN}Activo${NC}"
                        fi
                    fi
                    printf "%-12s %-20s %b\n" "$user" "$exp_info" "$status"
                done
            fi
            echo
            read -p "ENTER para continuar..."
            ;;

        7)
            clear
            show_header
            echo -e "${YELLOW}Eliminar Usuarios Expirados${NC}"
            echo
            
            deleted_count=0
            users_list=$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd)
            
            for user in $users_list; do
                exp_info=$(chage -l "$user" | grep "Account expires" | cut -d: -f2 | xargs)
                
                if [[ "$exp_info" != "never" ]] && [[ -n "$exp_info" ]]; then
                    exp_epoch=$(date -d "$exp_info" +%s 2>/dev/null)
                    now_epoch=$(date +%s)
                    
                    if [[ $exp_epoch -lt $now_epoch ]]; then
                        userdel "$user" 2>/dev/null
                        echo -e "${RED}🗑️  Usuario '$user' eliminado (Expiró el: $exp_info)${NC}"
                        ((deleted_count++))
                    fi
                fi
            done
            
            echo
            if [[ $deleted_count -eq 0 ]]; then
                echo -e "${GREEN}✅ No se encontraron usuarios expirados.${NC}"
            else
                echo -e "${GREEN}✅ Se eliminaron $deleted_count usuario(s) expirado(s).${NC}"
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
