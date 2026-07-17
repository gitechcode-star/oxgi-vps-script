#!/bin/bash
GREEN='\033[1;32m'; RED='\033[1;31m'; CYAN='\033[1;36m'; NC='\033[0m'
DB="/etc/oxgi/ssh_users.db"
mkdir -p /etc/oxgi

auto_kill() {
    # Esta función se llama desde cron o manualmente
    while IFS='|' read -r user pass max_dev created exp auto_del; do
        [[ -z "$user" ]] && continue
        # Contar sesiones activas de este usuario
        sessions=$(who | grep "^$user " | wc -l)
        if [[ $sessions -gt $max_dev ]]; then
            # Matar sesiones excedentes (deja solo 1 o las que permita max_dev)
            pkill -9 -u "$user"
            echo "$(date): Auto-kill triggered for $user ($sessions > $max_dev)" >> /var/log/oxgi_autokill.log
        fi
    done < "$DB"
}

create_user() {
    clear
    echo -e "${CYAN}=== CREAR USUARIO SSH ===${NC}"
    read -p "Usuario: " USER
    [[ -z "$USER" || $(id -u "$USER" &>/dev/null; echo $?) -eq 0 ]] && echo -e "${RED}Usuario vacio o existe${NC}" && read -p "ENTER" && return

    read -sp "Password: " PASS; echo ""
    read -p "Dispositivos maximos [1]: " DEV; DEV=${DEV:-1}
    
    echo "1) Dias  2) Horas  3) Minutos"
    read -p "Tipo de tiempo (1/2/3): " TYPE
    read -p "Cantidad: " AMT
    
    case $TYPE in
        1) EXP=$(date -d "+$AMT days" '+%Y-%m-%d %H:%M:%S');;
        2) EXP=$(date -d "+$AMT hours" '+%Y-%m-%d %H:%M:%S');;
        3) EXP=$(date -d "+$AMT minutes" '+%Y-%m-%d %H:%M:%S');;
        *) echo "Invalido"; read -p "ENTER"; return;;
    esac

    useradd -M -s /bin/false "$USER"
    echo "$USER:$PASS" | chpasswd
    
    AUTO_DEL=$(($(date -d "$EXP" +%s) + 172800)) # 2 días de gracia
    echo "$USER|$PASS|$DEV|$(date '+%Y-%m-%d %H:%M:%S')|$EXP|$AUTO_DEL" >> "$DB"

    clear
    echo -e "${GREEN}✅ USUARIO CREADO EXITOSAMENTE${NC}"
    echo -e "IP: $(curl -s https://api.ipify.org)"
    echo -e "User: ${GREEN}$USER${NC} | Pass: ${GREEN}$PASS${NC}"
    echo -e "Max Dispositivos: ${GREEN}$DEV${NC}"
    echo -e "Expira: ${RED}$EXP${NC}"
    read -p "ENTER"
}

list_users() {
    clear
    echo -e "${CYAN}=== USUARIOS ACTIVOS ===${NC}"
    [[ ! -f "$DB" ]] && echo "Sin usuarios" && read -p "ENTER" && return
    printf "%-15s %-10s %-20s %-10s\n" "Usuario" "Dispositivos" "Expiracion" "Estado"
    echo "--------------------------------------------------------"
    while IFS='|' read -r user pass dev created exp auto; do
        now=$(date +%s); exp_sec=$(date -d "$exp" +%s)
        if [[ $now -gt $auto ]]; then status="${RED}Eliminado${NC}"; userdel -r "$user" 2>/dev/null; sed -i "/^$user|/d" "$DB"
        elif [[ $now -gt $exp_sec ]]; then status="${YELLOW}Expirado${NC}"
        else status="${GREEN}Activo${NC}"; fi
        printf "%-15s %-10s %-20s %-10s\n" "$user" "$dev" "$exp" "$status"
    done < "$DB"
    read -p "ENTER"
}

# Menú
while true; do
    clear
    echo -e "${CYAN}=== SSH MANAGER ===${NC}"
    echo "1) Crear Usuario"
    echo "2) Ver Usuarios"
    echo "3) Ejecutar Auto-Kill Manual"
    echo "0) Salir"
    read -p "Opcion: " opt
    case $opt in
        1) create_user;;
        2) list_users;;
        3) auto_kill; echo "Verificación completada"; read -p "ENTER";;
        0) break;;
    esac
done
