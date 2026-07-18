#!/bin/bash

if [[ $EUID -ne 0 ]]; then
   echo -e "\e[31m[ERROR] Este script debe ejecutarse como root.\e[0m"
   exit 1
fi

GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

get_ip() {
    curl -s https://api.ipify.org || curl -s https://ifconfig.me
}

while true; do
    clear
    echo "══════════════════════════════════════"
    echo -e "        ${GREEN}WEBSOCKET MANAGER (SSH)${NC}"
    echo "══════════════════════════════════════"
    echo ""
    echo -e "  [1] ${GREEN}Instalar / Configurar WebSocket${NC}"
    echo -e "  [2] ${YELLOW}Reiniciar Servicios WebSocket${NC}"
    echo -e "  [3] ${YELLOW}Ver Estado y Puertos${NC}"
    echo -e "  [4] ${RED}Desinstalar WebSocket${NC}"
    echo ""
    echo -e "  [0] ${NC}Regresar al menú principal"
    echo "══════════════════════════════════════"
    echo ""
    read -p "Seleccione una opción [0-4]: " opt

    case $opt in
        1)
            clear
            echo -e "${GREEN}══════════════════════════════════════${NC}"
            echo -e "  Instalando WebSocket (Nginx + Websockify)"
            echo -e "${GREEN}══════════════════════════════════════${NC}"
            sleep 1

            echo -e "${YELLOW}[*] Actualizando repositorios...${NC}"
            apt update -y > /dev/null 2>&1
            apt install -y nginx websockify > /dev/null 2>&1

            if [[ $? -ne 0 ]]; then
                echo -e "${RED}[!] Error al instalar los paquetes.${NC}"
                read -p "Presiona ENTER para continuar..."
                continue
            fi

            systemctl is-active ssh >/dev/null 2>&1 || systemctl restart ssh

            rm -f /etc/nginx/sites-enabled/default

            cat > /etc/nginx/sites-available/websocket << 'EOF'
server {
    listen 80;
    server_name _;

    location /ws {
        proxy_pass http://127.0.0.1:8080;

        proxy_http_version 1.1;

        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

        proxy_cache_bypass $http_upgrade;

        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
    }
}
EOF

            ln -sf /etc/nginx/sites-available/websocket /etc/nginx/sites-enabled/websocket

            nginx -t > /dev/null 2>&1

            if [[ $? -ne 0 ]]; then
                echo -e "${RED}[ERROR] Configuración Nginx inválida.${NC}"
                read -p "Presiona ENTER para continuar..."
                continue
            fi

            cat > /etc/systemd/system/websockify.service << 'EOF'
[Unit]
Description=Websockify SSH Bridge Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/websockify 8080 127.0.0.1:22
Restart=always
RestartSec=3
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOF

            systemctl daemon-reload
            systemctl enable websockify >/dev/null 2>&1
            systemctl enable nginx >/dev/null 2>&1

            systemctl restart websockify
            systemctl restart nginx

            if command -v ufw >/dev/null && ufw status | grep -q "active"; then
                ufw allow 80/tcp >/dev/null 2>&1
            fi

            SERVER_IP=$(get_ip)

            clear
            echo -e "${GREEN}══════════════════════════════════════${NC}"
            echo -e "        ${GREEN}¡INSTALACIÓN EXITOSA!${NC}"
            echo -e "${GREEN}══════════════════════════════════════${NC}"
            echo ""
            echo -e "${YELLOW}DATOS DE CONEXIÓN:${NC}"
            echo -e "  • IP / Dominio : ${SERVER_IP}"
            echo -e "  • Puerto       : ${GREEN}80${NC}"
            echo -e "  • Path         : ${GREEN}/ws${NC}"
            echo ""
            read -p "Presiona ENTER para regresar..."
            ;;

        2)
            systemctl restart websockify
            systemctl restart nginx
            echo -e "${GREEN}[OK] Servicios reiniciados.${NC}"
            read -p "Presiona ENTER para continuar..."
            ;;

        3)
            clear
            echo -e "${GREEN}══════════════════════════════════════${NC}"
            echo -e "        ESTADO DE LOS SERVICIOS"
            echo -e "${GREEN}══════════════════════════════════════${NC}"
            echo ""

            echo -e "${YELLOW}► Nginx:${NC}"
            systemctl is-active nginx >/dev/null && echo -e "${GREEN}  [ACTIVO]${NC}" || echo -e "${RED}  [INACTIVO]${NC}"

            echo -e "${YELLOW}► Websockify:${NC}"
            systemctl is-active websockify >/dev/null && echo -e "${GREEN}  [ACTIVO]${NC}" || echo -e "${RED}  [INACTIVO]${NC}"

            echo ""
            echo -e "${YELLOW}► Puertos:${NC}"
            ss -tulpn | grep -E ':80|:443|:8080'
            echo ""

            read -p "Presiona ENTER para continuar..."
            ;;

        4)
            read -p "¿Desinstalar WebSocket? (s/n): " confirm

            if [[ "$confirm" == "s" || "$confirm" == "S" ]]; then
                systemctl stop websockify >/dev/null 2>&1
                systemctl disable websockify >/dev/null 2>&1

                rm -f /etc/systemd/system/websockify.service
                rm -f /etc/nginx/sites-available/websocket
                rm -f /etc/nginx/sites-enabled/websocket

                apt remove --purge -y websockify >/dev/null 2>&1

                systemctl daemon-reload
                systemctl restart nginx >/dev/null 2>&1

                echo -e "${GREEN}[OK] Desinstalado.${NC}"
            fi

            read -p "Presiona ENTER para continuar..."
            ;;

        0)
            break
            ;;

        *)
            echo -e "${RED}Opción inválida.${NC}"
            sleep 1
            ;;
    esac
done
