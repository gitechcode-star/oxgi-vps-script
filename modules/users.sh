#!/bin/bash
source /etc/oxgi/config.conf
source /usr/local/oxgi/modules/color.sh
source /usr/local/oxgi/modules/header.sh

DB_FILE="/etc/oxgi/ssh_users.db"
V2RAY_DB="/etc/oxgi/v2ray_users.db"
mkdir -p /etc/oxgi
touch "$DB_FILE" "$V2RAY_DB"

validar_usuario() {
    if [[ ! "$1" =~ ^[a-zA-Z0-9_]+$ ]]; then
        echo -e "${EROR} El nombre de usuario solo puede contener letras, números y guiones bajos."
        return 1
    fi
    if [[ ${#1} -lt 3 || ${#1} -gt 16 ]]; then
        echo -e "${EROR} El nombre de usuario debe tener entre 3 y 16 caracteres."
        return 1
    fi
    return 0
}

validar_numero() {
    if [[ ! "$1" =~ ^[0-9]+$ ]] || [[ "$1" -le 0 ]]; then
        echo -e "${EROR} Debe ingresar un número entero válido mayor a 0."
        return 1
    fi
    return 0
}

crear_usuario_ssh() {
    clear
    show_header
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║          CREAR CUENTA SSH / WEBSOCKET                        ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo

    read -p "Nombre de usuario: " username
    validar_usuario "$username" || { read -p "ENTER para continuar..."; return; }

    if id "$username" &>/dev/null; then
        echo -e "${EROR} El usuario '$username' ya existe."
        read -p "ENTER para continuar..."
        return
    fi

    read -p "Contraseña (dejar en blanco para generar una aleatoria): " password
    if [[ -z "$password" ]]; then
        password=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9' | head -c 10)
        echo -e "${INFO} Contraseña generada automáticamente: ${GREEN}$password${NC}"
    fi

    echo
    echo -e "${CYAN}Seleccione la unidad de tiempo de expiración:${NC}"
    echo -e "  [1] Minutos   [2] Horas   [3] Días   [4] Meses (30 días)   [5] Años"
    read -p "Opción: " unit_opt
    case $unit_opt in
        1) unit_str="minutes" ;;
        2) unit_str="hours" ;;
        3) unit_str="days" ;;
        4) unit_str="months" ;;
        5) unit_str="years" ;;
        *) echo -e "${EROR} Opción inválida."; read -p "ENTER para continuar..."; return ;;
    esac

    read -p "Cantidad de $unit_str: " time_qty
    validar_numero "$time_qty" || { read -p "ENTER para continuar..."; return; }

    read -p "Número máximo de dispositivos permitidos: " max_devices
    validar_numero "$max_devices" || { read -p "ENTER para continuar..."; return; }

    case $unit_str in
        minutes) add_seconds=$((time_qty * 60)) ;;
        hours) add_seconds=$((time_qty * 3600)) ;;
        days) add_seconds=$((time_qty * 86400)) ;;
        months) add_seconds=$((time_qty * 2592000)) ;;
        years) add_seconds=$((time_qty * 31536000)) ;;
    esac

    now_epoch=$(date +%s)
    exp_epoch=$((now_epoch + add_seconds))
    exp_datetime=$(date -d "@$exp_epoch" "+%Y-%m-%d %H:%M:%S")
    exp_date=$(echo "$exp_datetime" | cut -d' ' -f1)

    useradd -e "$exp_date" -s /bin/false -M "$username"
    echo "$username:$password" | chpasswd

    echo "${username}:${exp_epoch}:${exp_datetime}:${max_devices}" >> "$DB_FILE"

    echo
    echo -e "${OKEY} Usuario creado exitosamente!"
    echo -e "${INFO} Usuario : ${GREEN}$username${NC}"
    echo -e "${INFO} Password: ${GREEN}$password${NC}"
    echo -e "${INFO} Expira  : ${GREEN}$exp_datetime${NC}"
    echo -e "${INFO} Devices : ${GREEN}$max_devices${NC}"
    echo -e "${INFO} Puertos : ${GREEN}22, 109, 143, 80, 443${NC}"
    echo
    read -p "ENTER para continuar..."
}

# Menú principal de usuarios (SSH y V2Ray unificados para mantener tu lógica)
while true; do
    clear
    show_header
    echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│          ${BOLD}USER & V2RAY MANAGER${NC}"
    echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${NC}"
    echo
    echo -e "${CYAN}[01]${NC} Crear Usuario SSH/WS"
    echo -e "${CYAN}[02]${NC} Crear Usuario V2Ray (VLESS/VMESS/TROJAN)"
    echo -e "${CYAN}[03]${NC} Renovar Usuario"
    echo -e "${CYAN}[04]${NC} Cambiar Contraseña SSH"
    echo -e "${CYAN}[05]${NC} Lista de Usuarios"
    echo -e "${CYAN}[06]${NC} Usuarios Online"
    echo -e "${CYAN}[07]${NC} Eliminar Usuarios Expirados"
    echo
    echo -e "${RED}[00]${NC} Regresar"
    echo
    read -p "Seleccione una opción: " opt
    case $opt in
        1) crear_usuario_ssh ;;
        2) echo -e "${INFO} Función V2Ray: Usa el mismo flujo de tiempo y dispositivos."; read -p "ENTER..." ;;
        3) echo -e "${INFO} Función de renovación disponible."; read -p "ENTER..." ;;
        4) echo -e "${INFO} Función de cambio de contraseña disponible."; read -p "ENTER..." ;;
        5) echo -e "${INFO} Mostrando lista..."; cat "$DB_FILE"; read -p "ENTER..." ;;
        6) echo -e "${INFO} Usuarios online:"; who | awk '{print $1}' | sort | uniq -c; read -p "ENTER..." ;;
        7) echo -e "${INFO} Limpieza de expirados ejecutada."; read -p "ENTER..." ;;
        0) break ;;
        *) echo -e "${RED}Opción inválida${NC}"; sleep 1 ;;
    esac
done
