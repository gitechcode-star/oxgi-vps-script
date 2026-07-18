#!/bin/bash

if [[ $EUID -ne 0 ]]; then
   echo -e "\e[31m[ERROR] Requiere root.${NC}\e[0m"
   exit 1
fi

GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

install_nginx() {
    clear
    echo -e "${GREEN}══════════════════════════════════════${NC}"
    echo -e "      INSTALANDO NGINX"
    echo -e "${GREEN}══════════════════════════════════════${NC}"
    
    apt update -y > /dev/null 2>&1
    apt install -y nginx > /dev/null 2>&1
    
    systemctl enable nginx > /dev/null 2>&1
    systemctl start nginx
    
    if command -v ufw > /dev/null; then
        ufw allow 'Nginx Full' > /dev/null 2>&1
    fi
    
    echo -e "${GREEN}[OK] Nginx instalado y activo.${NC}"
    read -p "Presiona ENTER..."
}

restart_nginx() {
    systemctl restart nginx
    echo -e "${GREEN}[OK] Nginx reiniciado.${NC}"
    read -p "Presiona ENTER..."
}

status_nginx() {
    clear
    echo -e "${GREEN}► Estado:$(systemctl is-active nginx > /dev/null && echo -e " ${GREEN}[ACTIVO]${NC}" || echo -e " ${RED}[INACTIVO]${NC}")"
    echo ""
    ss -tulpn | grep ':80\|:443'
    read -p "Presiona ENTER..."
}

test_config() {
    echo -e "${YELLOW}[*] Probando configuración...${NC}"
    nginx -t
    read -p "Presiona ENTER..."
}

# Nueva función: Configurar Nginx con SSL para WebSocket
setup_ssl_websocket() {
    clear
    echo -e "${GREEN}══════════════════════════════════════${NC}"
    echo -e "  CONFIGURAR SSL + WEBSOCKET EN NGINX"
    echo -e "${GREEN}══════════════════════════════════════${NC}"
    echo ""
    
    read -p "Dominio (ej: tu-dominio.com): " DOMAIN
    if [[ -z "$DOMAIN" ]]; then
        echo -e "${RED}[!] Dominio requerido.${NC}"
        read -p "Presiona ENTER..."
        return 1
    fi
    
    # Verificar que existan certificados
    CERT_PATH="/etc/letsencrypt/live/${DOMAIN}"
    if [[ ! -f "${CERT_PATH}/fullchain.pem" ]]; then
        echo -e "${RED}[!] No se encontró certificado SSL para ${DOMAIN}.${NC}"
        echo -e "${YELLOW}    Ejecuta primero 'Solicitar Certificado SSL' en el menú SSL.${NC}"
        read -p "Presiona ENTER..."
        return 1
    fi
    
    # Crear configuración SSL para WebSocket
    cat > /etc/nginx/sites-available/websocket-ssl << EOF
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name ${DOMAIN};

    # Certificados SSL
    ssl_certificate ${CERT_PATH}/fullchain.pem;
    ssl_certificate_key ${CERT_PATH}/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # WebSocket proxy
    proxy_buffering off;
    proxy_request_buffering off;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
        proxy_connect_timeout 60s;
        proxy_cache_bypass \$http_upgrade;
    }

    location /health {
        access_log off;
        return 200 "OK\n";
        add_header Content-Type text/plain;
    }
}

# Redirección HTTP a HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};
    return 301 https://\$server_name\$request_uri;
}
EOF

    rm -f /etc/nginx/sites-enabled/default
    rm -f /etc/nginx/sites-enabled/websocket
    ln -sf /etc/nginx/sites-available/websocket-ssl /etc/nginx/sites-enabled/websocket-ssl
    
    nginx -t
    if [[ $? -eq 0 ]]; then
        systemctl restart nginx
        echo -e "${GREEN}[OK] SSL + WebSocket configurado exitosamente.${NC}"
        echo ""
        echo -e "${YELLOW}📡 Datos de conexión segura:${NC}"
        echo -e "  • Dominio: ${DOMAIN}"
        echo -e "  • Puerto: ${GREEN}443${NC}"
        echo -e "  • SSL/TLS: ${GREEN}Activado${NC}"
    else
        echo -e "${RED}[!] Error en configuración de Nginx.${NC}"
    fi
    
    read -p "Presiona ENTER..."
}

while true; do
    clear
    echo "══════════════════════════════════════"
    echo -e "        ${GREEN}NGINX MANAGER${NC}"
    echo "══════════════════════════════════════"
    echo ""
    echo -e "  [1] ${GREEN}Instalar Nginx${NC}"
    echo -e "  [2] ${YELLOW}Reiniciar${NC}"
    echo -e "  [3] ${YELLOW}Ver Estado${NC}"
    echo -e "  [4] ${YELLOW}Probar Config${NC}"
    echo -e "  [5] ${GREEN}Configurar SSL + WebSocket${NC}"
    echo ""
    echo -e "  [0] ${NC}Regresar"
    echo "══════════════════════════════════════"
    read -p "Opción [0-5]: " opt

    case $opt in
        1) install_nginx ;;
        2) restart_nginx ;;
        3) status_nginx ;;
        4) test_config ;;
        5) setup_ssl_websocket ;;
        0) break ;;
        *) echo -e "${RED}Inválida${NC}"; sleep 1 ;;
    esac
done
