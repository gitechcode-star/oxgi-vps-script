#!/bin/bash
# ==========================================
# Nginx Configuration Module with WebSocket
# ==========================================

source /etc/oxgi/config.conf
source /usr/local/oxgi/modules/color.sh
source /usr/local/oxgi/modules/header.sh

install_nginx() {
    echo -e "${BLUE}Instalando Nginx...${NC}"
    apt-get update
    apt-get install -y nginx
    systemctl enable nginx
    echo -e "${GREEN}Nginx instalado${NC}"
}

configure_nginx_websocket() {
    echo -e "${BLUE}Configurando Nginx para WebSocket...${NC}"
    
    cat > /etc/nginx/sites-available/websocket << 'EOFNGINX'
map $http_upgrade $connection_upgrade {
    default upgrade;
    '' close;
}

server {
    listen 80;
    listen [::]:80;
    server_name DOMAIN_PLACEHOLDER;

    return 301 https://$server_name:443$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name DOMAIN_PLACEHOLDER;

    ssl_certificate /etc/letsencrypt/live/DOMAIN_PLACEHOLDER/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/DOMAIN_PLACEHOLDER/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # WebSocket Configuration
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        
        # CRITICAL: Pass ALL WebSocket headers
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # CRITICAL: Pass Sec-WebSocket-* headers explicitly
        proxy_set_header Sec-WebSocket-Version $http_sec_websocket_version;
        proxy_set_header Sec-WebSocket-Key $http_sec_websocket_key;
        proxy_set_header Sec-WebSocket-Protocol $http_sec_websocket_protocol;
        proxy_set_header Sec-WebSocket-Extensions $http_sec_websocket_extensions;
        
        # Timeouts
        proxy_connect_timeout 86400s;
        proxy_send_timeout 86400s;
        proxy_read_timeout 86400s;
        
        # Disable buffering for WebSocket
        proxy_buffering off;
        proxy_cache_bypass $http_upgrade;
        proxy_request_buffering off;
        proxy_socket_keepalive on;
    }

    location /health {
        access_log off;
        return 200 "OK";
        add_header Content-Type text/plain;
    }
}
EOFNGINX

    # Reemplazar DOMAIN_PLACEHOLDER con el dominio real
    sed -i "s/DOMAIN_PLACEHOLDER/${DOMAIN//\//\\/}/g" /etc/nginx/sites-available/websocket

    # Habilitar sitio
    ln -sf /etc/nginx/sites-available/websocket /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    nginx -t
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Configuración completada${NC}"
    else
        echo -e "${RED}Error en configuración${NC}"
        exit 1
    fi
}

restart_nginx() {
    echo -e "${BLUE}Reiniciando Nginx...${NC}"
    systemctl restart nginx
    sleep 2
    
    if systemctl is-active --quiet nginx; then
        echo -e "${GREEN}✓ Nginx funcionando${NC}"
    else
        echo -e "${RED}✗ Error${NC}"
    fi
}

# Menú
while true; do
    clear
    show_header
    echo "══════════════════════════════"
    echo " NGINX MANAGER"
    echo "══════════════════════════════"
    echo
    echo "[1] Instalar y Configurar"
    echo "[2] Reiniciar"
    echo "[3] Estado"
    echo
    echo "[0] Regresar"
    echo
    read -p "Opción: " opt

    case $opt in
        1)
            install_nginx
            configure_nginx_websocket
            restart_nginx
            read -p "ENTER..."
            ;;
        2)
            restart_nginx
            read -p "ENTER..."
            ;;
        3)
            systemctl status nginx --no-pager -l
            read -p "ENTER..."
            ;;
        0)
            break
            ;;
        *)
            echo "Inválida"
            sleep 1
            ;;
    esac
done
