#!/bin/bash
# ==========================================
# Nginx Configuration Module with WebSocket Support
# ==========================================

source /etc/oxgi/config.conf

install_nginx() {
    echo -e "${BLUE}Installing Nginx...${NC}"
    apt-get update
    apt-get install -y nginx
    systemctl enable nginx
    echo -e "${GREEN}Nginx installed successfully${NC}"
}

configure_nginx_websocket() {
    echo -e "${BLUE}Configuring Nginx for WebSocket...${NC}"
    
    # Create Nginx WebSocket configuration
    cat > /etc/nginx/sites-available/websocket << EOF
server {
    listen ${HTTP_PORT};
    listen [::]:${HTTP_PORT};
    server_name ${DOMAIN};

    # Redirect HTTP to HTTPS
    return 301 https://\$server_name:${HTTPS_PORT}\$request_uri;
}

server {
    listen ${HTTPS_PORT} ssl http2;
    listen [::]:${HTTPS_PORT} ssl http2;
    server_name ${DOMAIN};

    # SSL Configuration
    ssl_certificate ${SSL_CERT};
    ssl_certificate_key ${SSL_KEY};
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_session_tickets off;

    # OCSP Stapling
    ssl_stapling on;
    ssl_stapling_verify on;

    # Security Headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # WebSocket Configuration
    location / {
        proxy_pass http://127.0.0.1:${PROXY_PORT};
        proxy_http_version 1.1;
        
        # CRITICAL: WebSocket headers - This fixes the "Missing Sec-WebSocket-Version header" error
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
        
        # Disable buffering for WebSocket
        proxy_buffering off;
        proxy_cache_bypass \$http_upgrade;
        proxy_request_buffering off;
        
        # TCP nodelay for better performance
        proxy_socket_keepalive on;
    }

    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }

    # Error pages
    error_page 404 /404.html;
    error_page 500 502 503 504 /50x.html;
    
    location ~ ^/(404|50x)\.html$ {
        root /usr/share/nginx/html;
        internal;
    }
}
EOF

    # Enable site
    ln -sf /etc/nginx/sites-available/websocket /etc/nginx/sites-enabled/websocket
    rm -f /etc/nginx/sites-enabled/default
    
    # Test configuration
    nginx -t
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Nginx WebSocket configuration completed${NC}"
    else
        echo -e "${RED}Nginx configuration test failed${NC}"
        exit 1
    fi
}

restart_nginx() {
    echo -e "${BLUE}Restarting Nginx...${NC}"
    systemctl restart nginx
    sleep 2
    
    if systemctl is-active --quiet nginx; then
        echo -e "${GREEN}✓ Nginx running successfully${NC}"
    else
        echo -e "${RED}✗ Nginx failed to start${NC}"
        echo -e "${YELLOW}Check logs: journalctl -u nginx${NC}"
    fi
}

# Main execution
main() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Nginx WebSocket Configuration${NC}"
    echo -e "${BLUE}========================================${NC}"
    
    install_nginx
    configure_nginx_websocket
    restart_nginx
    
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Configuration Complete!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo -e "${YELLOW}WebSocket: wss://${DOMAIN}:${HTTPS_PORT}${NC}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
