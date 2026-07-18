#!/bin/bash
# ==========================================
# WebSocket Service Module
# ==========================================

source /etc/oxgi/config.conf

install_websockify() {
    echo -e "${BLUE}Installing WebSocket dependencies...${NC}"
    apt-get update
    apt-get install -y websockify python3 python3-pip nginx
    pip3 install wsproxy || true
    echo -e "${GREEN}Dependencies installed${NC}"
}

create_websockify_service() {
    echo -e "${BLUE}Creating WebSocket service...${NC}"
    
    cat > /etc/systemd/system/oxgi-ws.service << EOF
[Unit]
Description=OXGI WebSocket Proxy
After=network.target ssh.service
Wants=ssh.service

[Service]
Type=simple
User=root
ExecStart=/usr/bin/websockify --web=/var/www/html ${PROXY_PORT} 127.0.0.1:${SSH_PORT}
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=oxgi-ws

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable oxgi-ws
    echo -e "${GREEN}WebSocket service created${NC}"
}

start_websocket() {
    echo -e "${BLUE}Starting WebSocket service...${NC}"
    systemctl start oxgi-ws
    sleep 2
    
    if systemctl is-active --quiet oxgi-ws; then
        echo -e "${GREEN}✓ WebSocket service running${NC}"
    else
        echo -e "${RED}✗ WebSocket service failed${NC}"
        journalctl -u oxgi-ws -n 20
    fi
}

restart_websocket() {
    echo -e "${BLUE}Restarting WebSocket service...${NC}"
    systemctl restart oxgi-ws
    sleep 2
    
    if systemctl is-active --quiet oxgi-ws; then
        echo -e "${GREEN}✓ WebSocket restarted${NC}"
    else
        echo -e "${RED}✗ WebSocket failed to restart${NC}"
    fi
}

websocket_status() {
    echo -e "${BLUE}WebSocket Status:${NC}"
    systemctl status oxgi-ws --no-pager -l
    echo ""
    echo -e "${BLUE}Listening ports:${NC}"
    netstat -tlnp | grep -E ":(${PROXY_PORT}|${WS_PORT})" || echo "No ports listening"
}

# Main menu
while true; do
    clear
    echo "══════════════════════════════"
    echo " WEBSOCKET MANAGER"
    echo "══════════════════════════════"
    echo
    echo "[1] Instalar WebSocket"
    echo "[2] Reiniciar WebSocket"
    echo "[3] Estado WebSocket"
    echo
    echo "[0] Regresar"
    echo
    read -p "Seleccione una opción: " opt

    case $opt in
        1)
            install_websockify
            create_websockify_service
            start_websocket
            read -p "ENTER..."
            ;;
        2)
            restart_websocket
            read -p "ENTER..."
            ;;
        3)
            websocket_status
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
