#!/bin/bash
# ==========================================
# WebSocket Service Module
# ==========================================

source /etc/oxgi/config.conf
source /usr/local/oxgi/modules/color.sh
source /usr/local/oxgi/modules/header.sh

install_websockify() {
    echo -e "${BLUE}Instalando dependencias...${NC}"
    apt-get update
    apt-get install -y websockify python3 python3-pip nginx
    echo -e "${GREEN}Instalado${NC}"
}

create_service() {
    echo -e "${BLUE}Creando servicio...${NC}"
    
    cat > /etc/systemd/system/oxgi-ws.service << EOF
[Unit]
Description=OXGI WebSocket Proxy
After=network.target ssh.service
Wants=ssh.service

[Service]
Type=simple
User=root
ExecStart=/usr/bin/websockify 8080 127.0.0.1:22
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable oxgi-ws
    echo -e "${GREEN}Servicio creado${NC}"
}

start_service() {
    echo -e "${BLUE}Iniciando...${NC}"
    systemctl start oxgi-ws
    sleep 2
    
    if systemctl is-active --quiet oxgi-ws; then
        echo -e "${GREEN}✓ WebSocket activo en puerto 8080${NC}"
    else
        echo -e "${RED}✗ Error${NC}"
    fi
}

# Menú
while true; do
    clear
    show_header
    echo "══════════════════════════════"
    echo " WEBSOCKET MANAGER"
    echo "══════════════════════════════"
    echo
    echo "[1] Instalar"
    echo "[2] Reiniciar"
    echo "[3] Estado"
    echo
    echo "[0] Regresar"
    echo
    read -p "Opción: " opt

    case $opt in
        1)
            install_websockify
            create_service
            start_service
            read -p "ENTER..."
            ;;
        2)
            systemctl restart oxgi-ws
            sleep 2
            echo -e "${GREEN}Reiniciado${NC}"
            read -p "ENTER..."
            ;;
        3)
            systemctl status oxgi-ws --no-pager -l
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
