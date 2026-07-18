#!/bin/bash
clear

export DEBIAN_FRONTEND=noninteractive
GREEN='\033[1;32m'; RED='\033[1;31m'; YELLOW='\033[1;33m'; CYAN='\033[1;36m'; NC='\033[0m'

echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║        ${GREEN}OXGI VPS SCRIPT v1.0.0${NC}${CYAN}                  ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
echo ""

# Solicitar dominio
read -p "Dominio: " DOMAIN
[[ -z "$DOMAIN" ]] && { echo -e "${RED}Se requiere dominio${NC}"; exit 1; }

SERVER_IP=$(curl -s https://api.ipify.org)
read -p "Email: " EMAIL
[[ -z "$EMAIL" ]] && EMAIL="admin@${DOMAIN}"

echo ""
echo -e "${YELLOW}[*] Verificando DNS...${NC}"
DOMAIN_IP=$(dig +short "$DOMAIN" 2>/dev/null | head -n1)

if [[ "$DOMAIN_IP" != "$SERVER_IP" ]]; then
    echo -e "${RED}[ERROR] El dominio no apunta a ${SERVER_IP}${NC}"
    echo -e "  Apunta a: ${DOMAIN_IP}"
    exit 1
fi

echo -e "${GREEN}[OK] DNS verificado${NC}"
mkdir -p /etc/oxgi
echo "$DOMAIN" > /etc/oxgi/domain.conf

read -p "¿Continuar? (s/n): " CONFIRM
[[ "$CONFIRM" != "s" && "$CONFIRM" != "S" ]] && exit 1

clear
echo -e "${CYAN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}   INICIANDO INSTALACIÓN...${NC}"
echo -e "${CYAN}════════════════════════════════════════════${NC}"
echo ""

# 1. Actualizar
echo -e "${YELLOW}[1/8] Actualizando sistema...${NC}"
apt update -y > /dev/null 2>&1
apt upgrade -y > /dev/null 2>&1
apt install -y curl wget sudo ufw nginx certbot python3-certbot-nginx \
    websockify dropbear fail2ban unzip git dnsutils -y > /dev/null 2>&1

# 2. Firewall
echo -e "${YELLOW}[2/8] Configurando firewall...${NC}"
ufw --force reset > /dev/null 2>&1
ufw allow 22/tcp > /dev/null 2>&1
ufw allow 80/tcp > /dev/null 2>&1
ufw allow 443/tcp > /dev/null 2>&1
ufw allow 109/tcp > /dev/null 2>&1
ufw allow 7300/udp > /dev/null 2>&1
echo "y" | ufw enable > /dev/null 2>&1

# 3. Dropbear
echo -e "${YELLOW}[3/8] Configurando Dropbear...${NC}"
sed -i 's/NO_START=1/NO_START=0/' /etc/default/dropbear
sed -i 's/DROPBEAR_PORT=22/DROPBEAR_PORT=109/' /etc/default/dropbear
systemctl enable --now dropbear > /dev/null 2>&1

# 4. BadVPN
echo -e "${YELLOW}[4/8] Instalando BadVPN...${NC}"
cd /tmp
git clone https://github.com/ambrop72/badvpn.git > /dev/null 2>&1
cd badvpn && mkdir build && cd build
cmake .. -DBUILD_UDPGW=ON > /dev/null 2>&1
make > /dev/null 2>&1
cp udpgw/badvpn-udpgw /usr/bin/

cat > /etc/systemd/system/badvpn.service << 'EOF'
[Service]
ExecStart=/usr/bin/badvpn-udpgw --listen-addr 127.0.0.1:7300
Restart=on-failure
[Install]
WantedBy=multi-user.target
EOF
systemctl enable --now badvpn > /dev/null 2>&1

# 5. Certificado SSL REAL
echo -e "${YELLOW}[5/8] Instalando SSL REAL con Certbot...${NC}"
systemctl stop nginx > /dev/null 2>&1

certbot certonly --standalone \
    -d "$DOMAIN" \
    --email "$EMAIL" \
    --non-interactive \
    --agree-tos > /dev/null 2>&1

if [[ $? -ne 0 ]]; then
    echo -e "${RED}[ERROR] Falló la instalación del SSL${NC}"
    exit 1
fi

echo -e "${GREEN}[OK] SSL REAL instalado${NC}"

# 6. Configuración CRÍTICA de Nginx para WebSocket
echo -e "${YELLOW}[6/8] Configurando Nginx (WebSocket REAL)...${NC}"

rm -f /etc/nginx/sites-enabled/default

# Configuración CORRECTA para WebSocket SSH
cat > /etc/nginx/sites-available/oxgi << EOF
# HTTP - Puerto 80
server {
    listen 80;
    server_name ${DOMAIN};
    
    # WebSocket SSH
    location / {
        proxy_pass http://127.0.0.1:2090;
        proxy_http_version 1.1;
        
        # Headers CRÍTICOS para WebSocket
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        
        # Timeouts
        proxy_connect_timeout 86400s;
        proxy_send_timeout 86400s;
        proxy_read_timeout 86400s;
        
        # Desactivar buffering
        proxy_buffering off;
        proxy_cache off;
    }
}

# HTTPS - Puerto 443
server {
    listen 443 ssl http2;
    server_name ${DOMAIN};
    
    # SSL REAL de Let's Encrypt
    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    
    # WebSocket SSH
    location / {
        proxy_pass http://127.0.0.1:2090;
        proxy_http_version 1.1;
        
        # Headers CRÍTICOS para WebSocket
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        
        # Timeouts
        proxy_connect_timeout 86400s;
        proxy_send_timeout 86400s;
        proxy_read_timeout 86400s;
        
        # Desactivar buffering
        proxy_buffering off;
        proxy_cache off;
    }
}
EOF

ln -sf /etc/nginx/sites-available/oxgi /etc/nginx/sites-enabled/

# 7. Websockify (CORRECTO)
echo -e "${YELLOW}[7/8] Configurando Websockify...${NC}"

cat > /etc/systemd/system/websockify.service << 'EOF'
[Unit]
Description=Websockify SSH
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/websockify --web=/usr/share/nginx/html 2090 127.0.0.1:22
Restart=on-failure
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now websockify nginx > /dev/null 2>&1

# 8. Renovación SSL
echo -e "${YELLOW}[8/8] Configurando auto-renovación...${NC}"
echo "0 3 * * * certbot renew --quiet && systemctl reload nginx" | crontab -

# Descargar panel
cd /usr/local
rm -rf oxgi
git clone https://github.com/gitechcode-star/oxgi-vps-script.git > /dev/null 2>&1
chmod +x oxgi/*.sh oxgi/modules/*.sh
ln -sf /usr/local/oxgi/oxgi.sh /usr/local/bin/oxgi

clear

# Verificar servicios
echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║        ${BOLD}INSTALACIÓN COMPLETADA${NC}${GREEN}                  ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
echo ""

SSL_STATUS=$(openssl x509 -in /etc/letsencrypt/live/${DOMAIN}/fullchain.pem -noout -dates 2>/dev/null && echo "OK" || echo "FAIL")

echo -e "${CYAN}════════════════════════════════════════════${NC}"
echo -e "${YELLOW}SERVICIOS:${NC}"
echo -e "${CYAN}════════════════════════════════════════════${NC}"

check_service() {
    if systemctl is-active --quiet $1; then
        echo -e "  ${GREEN}✓${NC} $2"
    else
        echo -e "  ${RED}✗${NC} $2"
    fi
}

check_service nginx "Nginx"
check_service websockify "Websockify (WebSocket)"
check_service dropbear "Dropbear (SSH)"
check_service badvpn "BadVPN (UDP)"

echo ""
echo -e "${CYAN}════════════════════════════════════════════${NC}"
echo -e "${YELLOW}PUERTOS:${NC}"
echo -e "${CYAN}════════════════════════════════════════════${NC}"
echo -e "  SSH WebSocket TLS  : ${GREEN}443${NC}"
echo -e "  SSH WebSocket HTTP : ${GREEN}80${NC}"
echo -e "  Dropbear SSH       : ${GREEN}109${NC}"
echo -e "  BadVPN UDP         : ${GREEN}7300${NC}"
echo ""
echo -e "${CYAN}════════════════════════════════════════════${NC}"
echo -e "${YELLOW}SSL CERTIFICATE:${NC}"
echo -e "${CYAN}════════════════════════════════════════════${NC}"
echo -e "  Dominio  : ${GREEN}${DOMAIN}${NC}"
echo -e "  Emisor   : ${GREEN}Let's Encrypt${NC}"
echo -e "  Estado   : ${GREEN}✓ INSTALADO${NC}"
echo ""
echo -e "${CYAN}════════════════════════════════════════════${NC}"
echo -e "${YELLOW}HTTP CUSTOM / INJECTOR:${NC}"
echo -e "${CYAN}════════════════════════════════════════════${NC}"
echo -e "  Host : ${GREEN}${DOMAIN}${NC}"
echo -e "  Port : ${GREEN}443${NC} (TLS) o ${GREEN}80${NC} (HTTP)"
echo -e "  Path : ${GREEN}/${NC}"
echo ""
echo -e "${GREEN}Escribe ${YELLOW}oxgi${GREEN} para gestionar${NC}"
echo ""

# Verificación final
echo -e "${CYAN}════════════════════════════════════════════${NC}"
echo -e "${YELLOW}VERIFICANDO WEBSOCKET...${NC}"
echo -e "${CYAN}════════════════════════════════════════════${NC}"

sleep 2
if curl -s -I http://localhost:2090 > /dev/null 2>&1; then
    echo -e "  ${GREEN}✓ Websockify escuchando en puerto 2090${NC}"
else
    echo -e "  ${RED}✗ Websockify NO está escuchando${NC}"
    echo -e "  ${YELLOW}Ejecuta: systemctl start websockify${NC}"
fi

if netstat -tlnp | grep -q ":80 "; then
    echo -e "  ${GREEN}✓ Nginx escuchando en puerto 80${NC}"
else
    echo -e "  ${RED}✗ Nginx NO está escuchando en 80${NC}"
fi

if netstat -tlnp | grep -q ":443 "; then
    echo -e "  ${GREEN}✓ Nginx escuchando en puerto 443${NC}"
else
    echo -e "  ${RED}✗ Nginx NO está escuchando en 443${NC}"
fi

echo ""
