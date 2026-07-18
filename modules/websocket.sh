#!/bin/bash
# ==========================================
# WebSocket Service Module
# ==========================================

source /etc/oxgi/config.conf
source /usr/local/oxgi/modules/color.sh
source /usr/local/oxgi/modules/header.sh

install_websockify() {
    echo -e "${BLUE}Instalando WebSocket dependencies...${NC}"
    apt-get update
    apt-get install -y websockify python3 python3-pip
    echo -e "${GREEN}Dependencias instaladas${NC}"
}

create_websockify_service() {
    echo -e "${BLUE}Creando servicio WebSocket...${NC}"
    
    cat > /etc/systemd/system/oxgi-ws.service << EOF
[Unit]
Description=OXGI WebSocket Proxy Service
After=network.target ssh.service
Wants=ssh.service

[Service]
Type=simple
User=root
ExecStart=/usr/bin/websockify 8080 127.0.0.1:${SSH_PORT:-22}
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
    echo -e "${GREEN}Servicio WebSocket creado${NC}"
}

start_websocket() {
    echo -e "${BLUE}Iniciando WebSocket...${NC}"
    systemctl start oxgi-ws
    sleep 2
    
    if systemctl is-active --quiet oxgi-ws; then
        echo -e "${GREEN}✓ WebSocket iniciado${NC}"
        echo -e "${GREEN}✓ Proxy: 127.0.0.1:8080 -> SSH:${SSH_PORT:-22}${NC}"
    else
        echo -e "${RED}✗ Error al iniciar WebSocket${NC}"
        journalctl -u oxgi-ws -n 10
    fi
}

restart_websocket() {
    echo -e "${BLUE}Reiniciando WebSocket...${NC}"
    systemctl restart oxgi-ws
    sleep 2
    
    if systemctl is-active --quiet oxgi-ws; then
        echo -e "${GREEN}✓ WebSocket reiniciado${NC}"
    else
        echo -e "${RED} Error${NC}"
    fi
}

websocket_status() {
    echo -e "${BLUE}Estado de WebSocket:${NC}"
    systemctl status oxgi-ws --no-pager -l
    echo ""
    echo -e "${BLUE}Puertos escuchando:${NC}"
    netstat -tlnp | grep -E ":(8080|${WS_PORT:-700})" || echo "No hay puertos"
}

# Menú principal
while true; do
    clear
    show_header
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
