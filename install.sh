#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# OXGI VPS SCRIPT - Instalador Profesional
# Dropbear: 90, 109, 143 | SSH WS: 80/443 | Stunnel: 447/777
# ═══════════════════════════════════════════════════════════════

export DEBIAN_FRONTEND=noninteractive
GREEN='\033[1;32m'; RED='\033[1;31m'; YELLOW='\033[1;33m'; CYAN='\033[1;36m'; NC='\033[0m'; BOLD='\033[1m'

echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   ${GREEN}OXGI VPS - Instalador Profesional${NC}${CYAN}            ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
echo ""

# ═══════════════════════════════════════════════════════════════
# SOLICITAR DOMINIO
# ═══════════════════════════════════════════════════════════════

echo -e "${YELLOW}══════════════════════════════════════════════════${NC}"
echo -e "  CONFIGURACIÓN DE DOMINIO"
echo -e "${YELLOW}══════════════════════════════════════════════════${NC}"
echo ""
echo -e "  Ingresa tu dominio para configurar SSL automático."
echo -e "  Si no tienes dominio, presiona ENTER para usar la IP."
echo ""
read -p "Dominio (ej: vps.midominio.com): " DOMAIN

# Obtener IP del servidor
SERVER_IP=$(curl -s https://api.ipify.org 2>/dev/null || echo "127.0.0.1")

if [[ -z "$DOMAIN" ]]; then
    echo -e "${YELLOW}[INFO] No se ingresó dominio. Se usará la IP: ${SERVER_IP}${NC}"
    DOMAIN="$SERVER_IP"
    USE_SSL=false
else
    echo -e "${YELLOW}[INFO] Verificando dominio: ${DOMAIN}${NC}"
    
    # Verificar que el dominio apunte a la IP del servidor
    DOMAIN_IP=$(dig +short "$DOMAIN" 2>/dev/null | head -n1)
    
    if [[ "$DOMAIN_IP" == "$SERVER_IP" ]]; then
        echo -e "${GREEN}[OK] El dominio apunta correctamente a este servidor.${NC}"
        USE_SSL=true
    else
        echo -e "${RED}[!] El dominio NO apunta a este servidor.${NC}"
        echo -e "  IP del dominio: ${DOMAIN_IP}"
        echo -e "  IP del servidor: ${SERVER_IP}"
        echo ""
        read -p "¿Continuar de todos modos? (s/n): " CONTINUE
        if [[ "$CONTINUE" != "s" && "$CONTINUE" != "S" ]]; then
            echo -e "${RED}[!] Instalación cancelada. Configura el DNS y vuelve a intentarlo.${NC}"
            exit 1
        fi
        USE_SSL=false
    fi
fi

# Guardar dominio para uso futuro
mkdir -p /etc/oxgi
echo "$DOMAIN" > /etc/oxgi/domain.conf
echo ""

# ═══════════════════════════════════════════════════════════════
# PASO 1: Actualización
# ═══════════════════════════════════════════════════════════════

echo -e "${YELLOW}[1/7] Actualizando sistema...${NC}"
apt update -y > /dev/null 2>&1
apt upgrade -y > /dev/null 2>&1
apt install -y curl wget sudo cron ufw nginx python3 jq bc stunnel4 \
    build-essential cmake openssl libssl-dev websockify dropbear \
    fail2ban vnstat unzip git dnsutils certbot python3-certbot-nginx > /dev/null 2>&1
echo -e "${GREEN}[OK] Sistema actualizado${NC}"

# ═══════════════════════════════════════════════════════════════
# PASO 2: Firewall (Incluye puerto 90 para Dropbear)
# ═══════════════════════════════════════════════════════════════

echo -e "${YELLOW}[2/7] Configurando Firewall...${NC}"
ufw --force reset > /dev/null 2>&1
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP WebSocket
ufw allow 443/tcp   # HTTPS WebSocket
ufw allow 90/tcp    # Dropbear (principal)
ufw allow 109/tcp   # Dropbear (adicional)
ufw allow 143/tcp   # Dropbear (adicional)
ufw allow 447/tcp   # Stunnel SSH
ufw allow 777/tcp   # Stunnel Dropbear
ufw allow 7100:7300/udp  # BadVPN
echo "y" | ufw enable > /dev/null 2>&1
echo -e "${GREEN}[OK] Firewall configurado (Puertos: 22, 80, 443, 90, 109, 143, 447, 777, 7100-7300)${NC}"

# ═══════════════════════════════════════════════════════════════
# PASO 3: Certificado SSL Temporal
# ═══════════════════════════════════════════════════════════════

echo -e "${YELLOW}[3/7] Generando certificado SSL temporal...${NC}"
mkdir -p /etc/nginx/ssl
openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/oxgi.key \
    -out /etc/nginx/ssl/oxgi.crt \
    -subj "/C=MY/ST=Selangor/L=Kuala Lumpur/O=OXGI/CN=${DOMAIN}" > /dev/null 2>&1
echo -e "${GREEN}[OK] Certificado temporal generado${NC}"

# ═══════════════════════════════════════════════════════════════
# PASO 4: Nginx + WebSocket
# ══════════════════════════════════════════════════════════════

echo -e "${YELLOW}[4/7] Configurando Nginx WebSocket...${NC}"
rm -f /etc/nginx/sites-enabled/default

cat > /etc/nginx/sites-available/oxgi-ws << EOF
# HTTP - Puerto 80
server {
    listen 80;
    server_name ${DOMAIN} _;
    
    keepalive_timeout 86400s;
    
    location / {
        proxy_pass http://127.0.0.1:2090;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_connect_timeout 86400s;
        proxy_send_timeout 86400s;
        proxy_read_timeout 86400s;
        proxy_buffering off;
    }
}

# HTTPS - Puerto 443
server {
    listen 443 ssl http2;
    server_name ${DOMAIN} _;
    
    ssl_certificate /etc/nginx/ssl/oxgi.crt;
    ssl_certificate_key /etc/nginx/ssl/oxgi.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    
    keepalive_timeout 86400s;
    
    location / {
        proxy_pass http://127.0.0.1:2090;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host \$host;
        proxy_connect_timeout 86400s;
        proxy_send_timeout 86400s;
        proxy_read_timeout 86400s;
        proxy_buffering off;
    }
}
EOF

ln -sf /etc/nginx/sites-available/oxgi-ws /etc/nginx/sites-enabled/

# Websockify
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
echo -e "${GREEN}[OK] Nginx y Websockify configurados${NC}"

# ═══════════════════════════════════════════════════════════════
# PASO 5: Dropbear (Puertos 90, 109, 143) + Stunnel
# ═══════════════════════════════════════════════════════════════

echo -e "${YELLOW}[5/7] Configurando Dropbear (90, 109, 143) y Stunnel...${NC}"

# Configurar Dropbear con puerto 90 como principal
sed -i 's/NO_START=1/NO_START=0/' /etc/default/dropbear
sed -i 's/DROPBEAR_PORT=22/DROPBEAR_PORT=90/' /etc/default/dropbear
echo 'DROPBEAR_EXTRA_ARGS="-p 109 -p 143 -w -s -j -k"' >> /etc/default/dropbear
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
connect = 127.0.0.1:90
EOF

openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
    -subj "/C=MY/ST=Selangor/L=KL/O=OXGI/CN=${DOMAIN}" \
    -keyout /etc/stunnel/stunnel.pem -out /etc/stunnel/stunnel.pem > /dev/null 2>&1

sed -i 's/ENABLED=0/ENABLED=1/' /etc/default/stunnel4
systemctl enable --now stunnel4
echo -e "${GREEN}[OK] Dropbear y Stunnel configurados${NC}"

# ═══════════════════════════════════════════════════════════════
# PASO 6: BadVPN + Panel
# ═══════════════════════════════════════════════════════════════

echo -e "${YELLOW}[6/7] Instalando BadVPN y Panel OXGI...${NC}"
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
echo -e "${GREEN}[OK] BadVPN y Panel instalados${NC}"

# ═══════════════════════════════════════════════════════════════
# PASO 7: Instalar Certificado SSL Real (Si hay dominio válido)
# ═══════════════════════════════════════════════════════════════

if [[ "$USE_SSL" == true ]]; then
    echo -e "${YELLOW}[7/7] Instalando certificado SSL Let's Encrypt...${NC}"
    
    # Detener Nginx temporalmente para que Certbot pueda usar el puerto 80
    systemctl stop nginx
    
    # Solicitar certificado con Certbot
    certbot certonly --standalone -d "$DOMAIN" --non-interactive --agree-tos --email admin@"${DOMAIN#*.}" > /dev/null 2>&1
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}[OK] Certificado SSL instalado exitosamente${NC}"
        
        # Actualizar configuración de Nginx con el certificado real
        cat > /etc/nginx/sites-available/oxgi-ws << EOF
# HTTP - Redirección a HTTPS
server {
    listen 80;
    server_name ${DOMAIN};
    return 301 https://\$host\$request_uri;
}

# HTTP - Puerto 8080 (para WebSocket sin TLS)
server {
    listen 8080;
    server_name ${DOMAIN} _;
    
    keepalive_timeout 86400s;
    
    location / {
        proxy_pass http://127.0.0.1:2090;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host \$host;
        proxy_connect_timeout 86400s;
        proxy_send_timeout 86400s;
        proxy_read_timeout 86400s;
        proxy_buffering off;
    }
}

# HTTPS - Puerto 443 (con certificado real)
server {
    listen 443 ssl http2;
    server_name ${DOMAIN};
    
    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    
    keepalive_timeout 86400s;
    
    location / {
        proxy_pass http://127.0.0.1:2090;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host \$host;
        proxy_connect_timeout 86400s;
        proxy_send_timeout 86400s;
        proxy_read_timeout 86400s;
        proxy_buffering off;
    }
}
EOF
        
        systemctl start nginx
        
        # Configurar renovación automática
        echo "0 3 * * * certbot renew --quiet && systemctl reload nginx" | crontab -
        
        echo -e "${GREEN}[OK] Nginx reiniciado con certificado real${NC}"
    else
        echo -e "${YELLOW}[WARN] No se pudo instalar el certificado SSL.${NC}"
        echo -e "${YELLOW}Se mantendrá el certificado temporal.${NC}"
        systemctl start nginx
    fi
else
    echo -e "${YELLOW}[7/7] Omitiendo instalación de SSL (sin dominio válido)${NC}"
fi

# ═══════════════════════════════════════════════════════════════
# RESUMEN FINAL
# ═══════════════════════════════════════════════════════════════

clear
echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║        ¡INSTALACIÓN COMPLETADA EXITOSAMENTE!     ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "${YELLOW} INFORMACIÓN DEL SERVIDOR:${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "  • IP: ${GREEN}${SERVER_IP}${NC}"
echo -e "  • Dominio: ${GREEN}${DOMAIN}${NC}"
if [[ "$USE_SSL" == true ]]; then
    echo -e "  • SSL: ${GREEN}Let's Encrypt (Certificado Real)${NC}"
else
    echo -e "  • SSL: ${YELLOW}Autofirmado (Temporal)${NC}"
fi
echo ""
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "${YELLOW} CONFIGURACIÓN PARA HTTP CUSTOM / INJECTOR:${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "  • Host/IP: ${GREEN}${DOMAIN}${NC}"
echo -e "  • Puerto HTTP: ${GREEN}80${NC}"
echo -e "  • Puerto HTTPS: ${GREEN}443${NC}"
echo -e "  • Path: ${GREEN}/${NC}"
echo ""
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}🔒 SERVICIOS Y PUERTOS:${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "  • OpenSSH: 22"
echo -e "  • SSH WebSocket: 80"
echo -e "  • SSH SSL WebSocket: 443"
echo -e "  • Dropbear: ${GREEN}90, 109, 143${NC}"
echo -e "  • Stunnel: 447, 777"
echo -e "  • BadVPN UDP: 7300"
echo ""
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}⚙️  FUNCIONES AUTOMÁTICAS:${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "  • Auto-Reboot: 5:00 AM"
echo -e "  • Auto-Delete: 2 días después de expirar"
echo -e "  • Auto-Kill: Multi-login excedente"
echo ""
echo -e "${GREEN}══════════════════════════════════════════════════${NC}"
echo -e "  Escribe ${YELLOW}${BOLD}oxgi${NC}${GREEN} para abrir el panel${NC}"
echo -e "${GREEN}══════════════════════════════════════════════════${NC}"
echo ""
