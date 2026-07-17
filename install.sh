#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# OXGI VPS SCRIPT - Optimizado para HTTP Custom / Injector
# ═══════════════════════════════════════════════════════════════

export DEBIAN_FRONTEND=noninteractive
GREEN='\033[1;32m'; RED='\033[1;31m'; YELLOW='\033[1;33m'; CYAN='\033[1;36m'; NC='\033[0m'

echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   ${GREEN}OXGI VPS - Optimizado HTTP Custom/Injector${NC}${CYAN}     ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"

# 1. Actualización
echo -e "${YELLOW}[1/6] Actualizando sistema...${NC}"
apt update -y && apt upgrade -y
apt install -y curl wget sudo cron ufw nginx python3 jq bc stunnel4 \
    build-essential cmake openssl libssl-dev websockify dropbear \
    fail2ban vnstat unzip git

# 2. Firewall
echo -e "${YELLOW}[2/6] Configurando Firewall...${NC}"
ufw --force reset
ufw allow 22/tcp
ufw allow 80/tcp    # HTTP WebSocket (CRÍTICO)
ufw allow 443/tcp   # HTTPS WebSocket (CRÍTICO)
ufw allow 447/tcp   # Stunnel
ufw allow 777/tcp   # Stunnel
ufw allow 109/tcp   # Dropbear
ufw allow 143/tcp   # Dropbear
ufw allow 7100:7300/udp  # BadVPN
echo "y" | ufw enable > /dev/null 2>&1

# 3. Certificado SSL (Auto-firmado para apps)
echo -e "${YELLOW}[3/6] Generando certificado SSL...${NC}"
mkdir -p /etc/nginx/ssl
openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/oxgi.key \
    -out /etc/nginx/ssl/oxgi.crt \
    -subj "/C=MY/ST=Selangor/L=Kuala Lumpur/O=OXGI/CN=oxgi.local" > /dev/null 2>&1

# 4. Nginx + WebSocket (CONFIGURACIÓN CRÍTICA PARA INJECTOR)
echo -e "${YELLOW}[4/6] Configurando Nginx WebSocket (Puertos 80/443)...${NC}"
rm -f /etc/nginx/sites-enabled/default

cat > /etc/nginx/sites-available/oxgi-ws << 'EOF'
# HTTP - Puerto 80 (Non-TLS)
server {
    listen 80;
    server_name _;
    
    # Keep-Alive largo para conexiones persistentes
    keepalive_timeout 86400s;
    
    location / {
        proxy_pass http://127.0.0.1:2090;
        proxy_http_version 1.1;
        
        # Headers CRÍTICOS para WebSocket
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        
        # Timeouts largos (24 horas)
        proxy_connect_timeout 86400s;
        proxy_send_timeout 86400s;
        proxy_read_timeout 86400s;
        
        # Buffer settings
        proxy_buffering off;
        proxy_cache_bypass $http_upgrade;
    }
}

# HTTPS - Puerto 443 (TLS)
server {
    listen 443 ssl http2;
    server_name _;
    
    ssl_certificate /etc/nginx/ssl/oxgi.crt;
    ssl_certificate_key /etc/nginx/ssl/oxgi.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    
    keepalive_timeout 86400s;
    
    location / {
        proxy_pass http://127.0.0.1:2090;
        proxy_http_version 1.1;
        
        # Headers CRÍTICOS para WebSocket
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        
        # Timeouts largos
        proxy_connect_timeout 86400s;
        proxy_send_timeout 86400s;
        proxy_read_timeout 86400s;
        
        proxy_buffering off;
        proxy_cache_bypass $http_upgrade;
    }
}
EOF

ln -sf /etc/nginx/sites-available/oxgi-ws /etc/nginx/sites-enabled/

# Websockify (Puente WebSocket -> SSH)
cat > /etc/systemd/system/websockify.service << 'EOF'
[Unit]
Description=Websockify SSH Bridge
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/websockify 2090 127.0.0.1:22
Restart=on-failure
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now websockify nginx

# 5. Dropbear + Stunnel
echo -e "${YELLOW}[5/6] Configurando Dropbear y Stunnel...${NC}"
sed -i 's/NO_START=1/NO_START=0/' /etc/default/dropbear
sed -i 's/DROPBEAR_PORT=22/DROPBEAR_PORT=109/' /etc/default/dropbear
echo 'DROPBEAR_EXTRA_ARGS="-p 143 -w -s -j -k"' >> /etc/default/dropbear
systemctl enable --now dropbear

# Stunnel
cat > /etc/stunnel/stunnel.conf << 'EOF'
cert = /etc/stunnel/stunnel.pem
sslVersion = TLSv1.2
options = NO_SSLv2
options = NO_SSLv3

[ssh-447]
accept = 447
connect = 127.0.0.1:22

[dropbear-777]
accept = 777
connect = 127.0.0.1:109
EOF

openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
    -subj "/C=MY/ST=Selangor/L=KL/O=OXGI/CN=oxgi.local" \
    -keyout /etc/stunnel/stunnel.pem -out /etc/stunnel/stunnel.pem > /dev/null 2>&1

sed -i 's/ENABLED=0/ENABLED=1/' /etc/default/stunnel4
systemctl enable --now stunnel4

# 6. BadVPN + Panel
echo -e "${YELLOW}[6/6] Instalando BadVPN y Panel OXGI...${NC}"
mkdir -p /tmp/badvpn && cd /tmp/badvpn
git clone https://github.com/ambrop72/badvpn.git . > /dev/null 2>&1
mkdir build && cd build
cmake .. -DBUILD_NOTHING_BY_DEFAULT=ON -DBUILD_UDPGW=ON > /dev/null 2>&1
make > /dev/null 2>&1
cp udpgw/badvpn-udpgw /usr/bin/

cat > /etc/systemd/system/badvpn.service << 'EOF'
[Unit]
Description=BadVPN UDPGW
[Service]
ExecStart=/usr/bin/badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 1000
Restart=on-failure
[Install]
WantedBy=multi-user.target
EOF

systemctl enable --now badvpn

# Instalar Panel
INSTALL_DIR="/usr/local/oxgi"
mkdir -p $INSTALL_DIR /etc/oxgi
git clone -b main https://github.com/gitechcode-star/oxgi-vps-script.git $INSTALL_DIR > /dev/null 2>&1
chmod +x $INSTALL_DIR/*.sh $INSTALL_DIR/modules/*.sh
ln -sf $INSTALL_DIR/oxgi.sh /usr/local/bin/oxgi

# Cron Jobs
(crontab -l 2>/dev/null; echo "0 5 * * * /sbin/reboot") | crontab -
(crontab -l 2>/dev/null; echo "0 * * * * /usr/local/oxgi/modules/auto_clean.sh") | crontab -

# Mostrar IP
IP=$(curl -s https://api.ipify.org)

clear
echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║        ¡INSTALACIÓN COMPLETADA EXITOSAMENTE!     ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}📡 CONFIGURACIÓN PARA HTTP CUSTOM / INJECTOR:${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "  • IP/VPS: ${GREEN}${IP}${NC}"
echo -e "  • Puerto 80 (HTTP WS): ${GREEN}ACTIVO${NC}"
echo -e "  • Puerto 443 (HTTPS WS): ${GREEN}ACTIVO${NC}"
echo -e "  • Path/Endpoint: ${GREEN}/${NC} (diagonal)"
echo -e "  • Host/SNI: ${GREEN}${IP}${NC} o cualquier dominio"
echo ""
echo -e "${CYAN}──────────────────────────────────────────────────${NC}"
echo -e "${YELLOW}🔧 OTROS SERVICIOS:${NC}"
echo -e "  • Dropbear: 109, 143"
echo -e "  • Stunnel: 447, 777"
echo -e "  • BadVPN UDP: 7300"
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}Escribe ${YELLOW}oxgi${GREEN} para abrir el panel${NC}"
echo ""
