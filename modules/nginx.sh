#!/bin/bash
source /etc/oxgi/config.conf
source /usr/local/oxgi/modules/color.sh
source /usr/local/oxgi/modules/header.sh

install_nginx() {
    echo -e "${INFO} Instalando Nginx..."
    apt-get update -y > /dev/null 2>&1
    apt-get install -y nginx > /dev/null 2>&1
    systemctl enable nginx > /dev/null 2>&1
}

configure_nginx() {
    echo -e "${INFO} Configurando Nginx (Puertos 80, 81, 443)..."
    
    if [[ ! -f /etc/oxgi/domain.conf ]]; then
        echo -e "${EROR} No se encontró /etc/oxgi/domain.conf"
        return 1
    fi
    DOMAIN=$(cat /etc/oxgi/domain.conf)

    cat > /etc/nginx/nginx.conf << 'EOFNGINX'
user www-data;
worker_processes 1;
pid /var/run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
    multi_accept on;
    worker_connections 1024;
}

http {
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    server_tokens off;
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;
    gzip on;
    gzip_vary on;
    gzip_comp_level 5;
    gzip_types text/plain application/x-javascript text/xml text/css;
    client_max_body_size 32M;
    client_header_buffer_size 8m;
    large_client_header_buffers 8 8m;
    
    # Cloudflare IP Ranges
    set_real_ip_from 204.93.240.0/24;
    set_real_ip_from 204.93.177.0/24;
    set_real_ip_from 199.27.128.0/21;
    set_real_ip_from 173.245.48.0/20;
    set_real_ip_from 103.21.244.0/22;
    set_real_ip_from 103.22.200.0/22;
    set_real_ip_from 103.31.4.0/22;
    set_real_ip_from 141.101.64.0/18;
    set_real_ip_from 108.162.192.0/18;
    set_real_ip_from 190.93.240.0/20;
    set_real_ip_from 188.114.96.0/20;
    set_real_ip_from 197.234.240.0/22;
    set_real_ip_from 198.41.128.0/17;
    real_ip_header CF-Connecting-IP;

    include /etc/nginx/conf.d/*.conf;
}
EOFNGINX

    cat > /etc/nginx/conf.d/websocket.conf << EOFWS
map \$http_upgrade \$connection_upgrade {
    default upgrade;
    '' close;
}

server {
    listen 80;
    server_name ${DOMAIN} _;
    
    location / {
        proxy_pass http://127.0.0.1:${WS_BACKEND_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header Sec-WebSocket-Version \$http_sec_websocket_version;
        proxy_set_header Sec-WebSocket-Key \$http_sec_websocket_key;
        proxy_connect_timeout 86400s;
        proxy_send_timeout 86400s;
        proxy_read_timeout 86400s;
        proxy_buffering off;
        proxy_request_buffering off;
    }
    
    location /vless { proxy_pass http://127.0.0.1:10001; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection \$connection_upgrade; proxy_buffering off; }
    location /vmess { proxy_pass http://127.0.0.1:10000; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection \$connection_upgrade; proxy_buffering off; }
    location /trojan { proxy_pass http://127.0.0.1:10002; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection \$connection_upgrade; proxy_buffering off; }
}

server {
    listen 443 ssl http2;
    server_name ${DOMAIN} _;
    
    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    
    location / {
        proxy_pass http://127.0.0.1:${WS_BACKEND_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header Sec-WebSocket-Version \$http_sec_websocket_version;
        proxy_set_header Sec-WebSocket-Key \$http_sec_websocket_key;
        proxy_buffering off;
        proxy_request_buffering off;
    }
    
    location /vless { proxy_pass http://127.0.0.1:10001; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection \$connection_upgrade; proxy_buffering off; }
    location /vmess { proxy_pass http://127.0.0.1:10000; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection \$connection_upgrade; proxy_buffering off; }
    location /trojan { proxy_pass http://127.0.0.1:10002; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection \$connection_upgrade; proxy_buffering off; }
}
EOFWS

    cat > /etc/nginx/conf.d/vps.conf << 'EOFVPS'
server {
    listen 81;
    server_name 127.0.0.1 localhost;
    root /home/vps/public_html;
    location / {
        index index.html index.htm index.php;
        try_files $uri $uri/ /index.php?$args;
    }
    location ~ \.php$ {
        include /etc/nginx/fastcgi_params;
        fastcgi_pass 127.0.0.1:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    }
}
EOFVPS

    rm -f /etc/nginx/sites-enabled/default
    nginx -t > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        systemctl restart nginx
        echo -e "${OKEY} Nginx configurado y reiniciado."
    else
        echo -e "${EROR} Error en la configuración de Nginx."
    fi
}

while true; do
    clear
    show_header
    echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│          ${BOLD}NGINX MANAGER${NC}"
    echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${NC}"
    echo
    echo -e "${CYAN}[01]${NC} Instalar y Configurar Nginx"
    echo -e "${CYAN}[02]${NC} Reiniciar Nginx"
    echo -e "${CYAN}[03]${NC} Estado de Nginx"
    echo
    echo -e "${RED}[00]${NC} Regresar"
    echo
    read -p "Seleccione una opción: " opt
    case $opt in
        1) install_nginx; configure_nginx; read -p "ENTER..." ;;
        2) systemctl restart nginx; echo -e "${OKEY} Reiniciado"; read -p "ENTER..." ;;
        3) systemctl status nginx --no-pager -l; read -p "ENTER..." ;;
        0) break ;;
        *) echo -e "${RED}Opción inválida${NC}"; sleep 1 ;;
    esac
done
