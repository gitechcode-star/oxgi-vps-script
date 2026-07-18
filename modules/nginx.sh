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
    echo -e "${GREEN}Nginx instalado correctamente${NC}"
}

configure_nginx_websocket() {
    echo -e "${BLUE}Configurando Nginx para WebSocket...${NC}"
    
    # Crear configuración de Nginx
    cat > /etc/nginx/sites-available/websocket << EOF
server {
    listen ${HTTP_PORT:-80};
    listen [::]:${HTTP_PORT:-80};
    server_name ${DOMAIN};

    # Redirigir HTTP a HTTPS
    return 301 https://\$server_name:${HTTPS_PORT:-443}\$request_uri;
}

server {
    listen ${HTTPS_PORT:-443} ssl http2;
    listen [::]:${HTTPS_PORT:-443} ssl http2;
    server_name ${DOMAIN};

    # SSL Configuration
    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # WebSocket Configuration - CRITICAL
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        
        # Headers esenciales para WebSocket
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # WebSocket timeouts
        proxy_connect_timeout 86400s;
        proxy_send_timeout 86400s;
        proxy_read_timeout 86400s;
        
        # Disable buffering
        proxy_buffering off;
        proxy_cache_bypass \$http_upgrade;
        proxy_request_buffering off;
    }

    # Health check
    location /health {
        access_log off;
        return 200 "OK";
        add_header Content-Type text/plain;
    }
}
EOF

    # Habilitar sitio
    ln -sf /etc/nginx/sites-available/websocket /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    # Probar configuración
    nginx -t
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Configuración de Nginx completada${NC}"
    else
        echo -e "${RED}Error en configuración de Nginx${NC}"
        exit 1
    fi
}

restart_nginx() {
    echo -e "${BLUE}Reiniciando Nginx...${NC}"
    systemctl restart nginx
    sleep 2
    
    if systemctl is-active --quiet nginx; then
        echo -e "${GREEN}✓ Nginx funcionando correctamente${NC}"
    else
        echo -e "${RED}✗ Error al iniciar Nginx${NC}"
    fi
}

# Menú principal
while true; do
    clear
    show_header
    echo "══════════════════════════════"
    echo " NGINX MANAGER"
    echo "══════════════════════════════"
    echo
    echo "[1] Instalar y Configurar Nginx"
    echo "[2] Reiniciar Nginx"
    echo "[3] Estado Nginx"
    echo
    echo "[0] Regresar"
    echo
    read -p "Seleccione una opción: " opt

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
            echo "Opción inválida"
            sleep 1
            ;;
    esac
done
