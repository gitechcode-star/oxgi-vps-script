#!/bin/bash
# ==========================================
# WebSocket Configuration Module (OXGI)
# ==========================================

source /etc/oxgi/config.conf

install_websocket() {
    echo -e "${BLUE}Instalando dependencias de WebSocket...${NC}"
    apt-get update
    apt-get install -y nginx websockify python3 python3-pip
    echo -e "${GREEN}Dependencias instaladas correctamente${NC}"
}

configure_nginx_websocket() {
    echo -e "${BLUE}Configurando Nginx para WebSocket...${NC}"
    
    # Crear configuración de Nginx usando las variables de config.conf
    cat > /etc/nginx/sites-available/websocket << EOF
server {
    listen ${HTTP_PORT};
    listen [::]:${HTTP_PORT};
    server_name ${DOMAIN};

    # Redirigir HTTP a HTTPS
    return 301 https://\$server_name:${HTTPS_PORT}\$request_uri;
}

server {
    listen ${HTTPS_PORT} ssl http2;
    listen [::]:${HTTPS_PORT} ssl http2;
    server_name ${DOMAIN};

    # Configuración SSL
    ssl_certificate ${SSL_CERT};
    ssl_certificate_key ${SSL_KEY};
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # Configuración WebSocket
    location / {
        proxy_pass http://127.0.0.1:${PROXY_PORT};
        proxy_http_version 1.1;
        
        # Headers CRÍTICOS para WebSocket (soluciona el error 400)
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Tiempos de espera para WebSocket
        proxy_connect_timeout 86400s;
        proxy_send_timeout 86400s;
        proxy_read_timeout 86400s;
        
        # Desactivar buffering para WebSocket
        proxy_buffering off;
        proxy_cache_bypass \$http_upgrade;
        proxy_request_buffering off;
    }
}
EOF

    # Habilitar el sitio
    ln -sf /etc/nginx/sites-available/websocket /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    # Probar configuración de Nginx
    nginx -t
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Configuración de Nginx completada${NC}"
    else
        echo -e "${RED}Error en la configuración de Nginx${NC}"
        exit 1
    fi
}

configure_websockify_service() {
    echo -e "${BLUE}Configurando servicio de Websockify...${NC}"
    
    cat > /etc/systemd/system/oxgi-ws.service << EOF
[Unit]
Description=OXGI WebSocket Proxy Service
After=network.target ssh.service

[Service]
Type=simple
ExecStart=/usr/bin/websockify ${PROXY_PORT} 127.0.0.1:${SSH_PORT}
Restart=on-failure
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable oxgi-ws
    echo -e "${GREEN}Servicio de Websockify configurado${NC}"
}

restart_services() {
    echo -e "${BLUE}Reiniciando servicios...${NC}"
    systemctl restart nginx
    systemctl restart oxgi-ws
    sleep 2
    
    if systemctl is-active --quiet nginx && systemctl is-active --quiet oxgi-ws; then
        echo -e "${GREEN}✓ Todos los servicios están funcionando correctamente${NC}"
        echo -e "${GREEN}✓ WebSocket disponible en: wss://${DOMAIN}:${HTTPS_PORT}${NC}"
    else
        echo -e "${RED}✗ Algunos servicios fallaron al iniciar${NC}"
        echo -e "${YELLOW}Revisa los logs: journalctl -u nginx -u oxgi-ws${NC}"
    fi
}

# Menú principal
while true; do
    clear
    echo "══════════════════════════════"
    echo " GESTOR DE WEBSOCKET (OXGI)"
    echo "══════════════════════════════"
    echo
    echo "[1] Instalar y Configurar WebSocket"
    echo "[2] Reiniciar Servicios"
    echo "[3] Ver Estado"
    echo
    echo "[0] Regresar"
    echo
    read -p "Seleccione una opción: " opt

    case $opt in
        1)
            install_websocket
            configure_nginx_websocket
            configure_websockify_service
            restart_services
            read -p "Presione ENTER para continuar..."
            ;;
        2)
            restart_services
            read -p "Presione ENTER para continuar..."
            ;;
        3)
            echo -e "${BLUE}Estado de Nginx:${NC}"
            systemctl status nginx --no-pager -l
            echo -e "${BLUE}Estado de Websockify:${NC}"
            systemctl status oxgi-ws --no-pager -l
            read -p "Presione ENTER para continuar..."
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
