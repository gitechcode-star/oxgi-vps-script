#!/bin/bash
# ==========================================
# Nginx Configuration Module (OXGI)
# ==========================================

if [[ -f /etc/oxgi/domain.conf ]]; then
    DOMAIN=$(cat /etc/oxgi/domain.conf)
else
    echo -e "\e[1;31mError: No se encontró /etc/oxgi/domain.conf\e[0m"
    echo "Ejecuta el script de instalación principal primero."
    exit 1
fi

echo -e "\e[1;36m[*] Configurando Nginx para WebSocket...\e[0m"

cat > /etc/nginx/sites-available/oxgi << EOF
map \$http_upgrade \$connection_upgrade {
    default upgrade;
    '' close;
}

# HTTP - Puerto 80
server {
    listen 80;
    server_name ${DOMAIN} _;
    
    location / {
        proxy_pass http://127.0.0.1:2090;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        
        # CRÍTICO: Forzar paso de headers de WebSocket (Soluciona error 400)
        proxy_set_header Sec-WebSocket-Version \$http_sec_websocket_version;
        proxy_set_header Sec-WebSocket-Key \$http_sec_websocket_key;
        
        proxy_connect_timeout 86400s;
        proxy_send_timeout 86400s;
        proxy_read_timeout 86400s;
        proxy_buffering off;
        proxy_request_buffering off;
    }
    
    location /vless {
        proxy_pass http://127.0.0.1:10000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_buffering off;
    }
    
    location /vmess {
        proxy_pass http://127.0.0.1:10001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_buffering off;
    }
    
    location /trojan {
        proxy_pass http://127.0.0.1:10002;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_buffering off;
    }
}

# HTTPS - Puerto 443
server {
    listen 443 ssl http2;
    server_name ${DOMAIN} _;
    
    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    
    location / {
        proxy_pass http://127.0.0.1:2090;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        
        # CRÍTICO: Forzar paso de headers de WebSocket (Soluciona error 400)
        proxy_set_header Sec-WebSocket-Version \$http_sec_websocket_version;
        proxy_set_header Sec-WebSocket-Key \$http_sec_websocket_key;
        
        proxy_connect_timeout 86400s;
        proxy_send_timeout 86400s;
        proxy_read_timeout 86400s;
        proxy_buffering off;
        proxy_request_buffering off;
    }
    
    location /vless {
        proxy_pass http://127.0.0.1:10000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_buffering off;
    }
    
    location /vmess {
        proxy_pass http://127.0.0.1:10001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_buffering off;
    }
    
    location /trojan {
        proxy_pass http://127.0.0.1:10002;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_buffering off;
    }
}
EOF

ln -sf /etc/nginx/sites-available/oxgi /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

nginx -t
if [ $? -eq 0 ]; then
    systemctl restart nginx
    echo -e "\e[1;32m[OK] Nginx configurado y reiniciado correctamente.\e[0m"
else
    echo -e "\e[1;31m[ERROR] Fallo en la configuración de Nginx.\e[0m"
fi
