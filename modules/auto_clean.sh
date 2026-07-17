#!/bin/bash
# Auto-limpieza de usuarios expirados (2 días después)

DB_FILE="/etc/oxgi/ssh_users.db"

if [[ ! -f "$DB_FILE" ]]; then
    exit 0
fi

current_ts=$(date +%s)
temp_file="${DB_FILE}.tmp"

> "$temp_file"

while IFS='|' read -r user pass devices created expiry auto_delete_ts; do
    if [[ -n "$user" ]]; then
        if [[ "$current_ts" -gt "$auto_delete_ts" ]]; then
            userdel -r "$user" 2>/dev/null
        else
            echo "${user}|${pass}|${devices}|${created}|${expiry}|${auto_delete_ts}" >> "$temp_file"
        fi
    fi
done < "$DB_FILE"

mv "$temp_file" "$DB_FILE"
