#!/bin/bash
# ==========================================
# Nginx Installation and Configuration
# ==========================================

source /etc/oxgi/config.conf
source /usr/local/oxgi/modules/color.sh

if [[ ! -f /etc/oxgi/domain.conf ]]; then
    echo -e "${EROR} No existe /etc/oxgi/domain.conf"
    echo -e "${INFO} Ejecuta el script de instalación principal primero"
    exit 1
fi

DOMAIN=$(cat /etc/oxgi/domain.conf)

echo -e "${INFO} Instalando Nginx..."
apt-get update -y > /dev/null 2>&1
apt-get install -y nginx > /dev/null 2>&1

echo -e "${INFO} Configurando Nginx..."

# Nginx.conf principal
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
    ##
    # Basic Settings
    ##

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    server_tokens off;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    ##
    # SSL Settings
    ##

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;

    ##
    # Logging Settings
    ##

    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    ##
    # Gzip Settings
    ##

    gzip on;
    gzip_vary on;
    gzip_comp_level 5;
    gzip_types text/plain application/x-javascript text/xml text/css application/xml;

    ##
    # Virtual Host Configs
    ##

    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
    
    client_max_body_size 32M;
    client_header_buffer_size 8m;
    large_client_header_buffers 8 8m;
    fastcgi_buffer_size 8m;
    fastcgi_buffers 8 8m;
    fastcgi_read_timeout 600;

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
}
EOFNGINX

# WebSocket + Xray Configuration
cat > /etc/nginx/conf.d/websocket.conf << EOFWS
map \$http_upgrade \$connection_upgrade {
    default upgrade;
    '' close;
}

# HTTP - Port 80 (WebSocket Non-TLS + Xray None TLS)
server {
    listen 80;
    server_name ${DOMAIN} _;
    
    # SSH WebSocket Non-TLS
    location / {
        proxy_pass http://127.0.0.1:2090;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Sec-WebSocket-Version \$http_sec_websocket_version;
        proxy_set_header Sec-WebSocket-Key \$http_sec_websocket_key;
        proxy_set_header Sec-WebSocket-Protocol \$http_sec_websocket_protocol;
        proxy_connect_timeout 86400s;
        proxy_send_timeout 86400s;
        proxy_read_timeout 86400s;
        proxy_buffering off;
        proxy_request_buffering off;
        proxy_socket_keepalive on;
    }
    
    # Xray Vmess None TLS
    location /vmess {
        proxy_pass http://127.0.0.1:10000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header Host \$host;
        proxy_buffering off;
        proxy_cache_bypass \$http_upgrade;
    }
    
    # Xray Vless None TLS
    location /vless {
        proxy_pass http://127.0.0.1:10001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header Host \$host;
        proxy_buffering off;
        proxy_cache_bypass \$http_upgrade;
    }
    
    # Xray Trojan None TLS
    location /trojan {
        proxy_pass http://127.0.0.1:10002;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header Host \$host;
        proxy_buffering off;
        proxy_cache_bypass \$http_upgrade;
    }
    
    # Xray Shadowsocks/Sodosok None TLS
    location /sodosok {
        proxy_pass http://127.0.0.1:10003;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header Host \$host;
        proxy_buffering off;
        proxy_cache_bypass \$http_upgrade;
    }
}

# HTTPS - Port 443 (WebSocket TLS + Xray TLS)
server {
    listen 443 ssl http2;
    server_name ${DOMAIN} _;
    
    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # SSH SSL WebSocket
    location / {
        proxy_pass http://127.0.0.1:2090;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Sec-WebSocket-Version \$http_sec_websocket_version;
        proxy_set_header Sec-WebSocket-Key \$http_sec_websocket_key;
        proxy_set_header Sec-WebSocket-Protocol \$http_sec_websocket_protocol;
        proxy_connect_timeout 86400s;
        proxy_send_timeout 86400s;
        proxy_read_timeout 86400s;
        proxy_buffering off;
        proxy_request_buffering off;
        proxy_socket_keepalive on;
    }
    
    # Xray Vmess TLS
    location /vmess {
        proxy_pass http://127.0.0.1:10000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header Host \$host;
        proxy_buffering off;
        proxy_cache_bypass \$http_upgrade;
    }
    
    # Xray Vless TLS
    location /vless {
        proxy_pass http://127.0.0.1:10001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header Host \$host;
        proxy_buffering off;
        proxy_cache_bypass \$http_upgrade;
    }
    
    # Xray Trojan TLS
    location /trojan {
        proxy_pass http://127.0.0.1:10002;
        proxy_http_version 1.1;
