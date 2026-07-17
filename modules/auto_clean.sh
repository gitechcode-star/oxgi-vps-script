#!/bin/bash
DB="/etc/oxgi/ssh_users.db"
[[ ! -f "$DB" ]] && exit 0

now=$(date +%s)
tmp="${DB}.tmp"
> "$tmp"

while IFS='|' read -r user pass dev created exp auto_del; do
    if [[ -n "$user" ]]; then
        if [[ $now -gt $auto_del ]]; then
            userdel -r "$user" 2>/dev/null
            logger "OXGI: Usuario $user eliminado (2 días después de expirar)"
        else
            echo "$user|$pass|$dev|$created|$exp|$auto_del" >> "$tmp"
        fi
    fi
done < "$DB"
mv "$tmp" "$DB"

# Auto-Kill Multi Login
while IFS='|' read -r user pass max_dev created exp auto_del; do
    sessions=$(who | grep "^$user " | wc -l)
    if [[ $sessions -gt $max_dev ]]; then
        pkill -9 -u "$user"
        logger "OXGI: Auto-kill $user ($sessions sesiones > $max_dev permitidas)"
    fi
done < "$DB"
