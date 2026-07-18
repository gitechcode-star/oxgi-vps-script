#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# OXGI VPS SCRIPT v1.0.0
# SSL REAL con Let's Encrypt (Certbot)
# ══════════════════════════════════════════════════════════════

clear

export DEBIAN_FRONTEND=noninteractive
GREEN='\033[1;32m'; RED='\033[1;31m'; YELLOW='\033[1;33m'; CYAN='\033[1;36m'; NC='\033[0m'; BOLD='\033[1m'

echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║           ${GREEN}${BOLD}OXGI VPS SCRIPT${NC}${CYAN} v1.0.0              ║${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════╝${NC}"
echo ""

# ═══════════════════════════════════════════════════════════════
# PASO 1: SOLICITAR DOMINIO Y EMAIL
# ═══════════════════════════════════════════════════════════════

echo -e "${YELLOW}══════════════════════════════════════════════════${NC}"
echo -e "  ${BOLD}DATOS PARA CERTIFICADO SSL REAL${NC}"
echo -e "${YELLOW}══════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${CYAN}Se instalará un certificado SSL REAL de:${NC}"
echo -e "  ${GREEN}Let's Encrypt (Autoridad Certificadora)${NC}"
echo ""

SERVER_IP=$(curl -s https://api.ipify.org 2>/dev/null)
echo -e "  IP del Servidor: ${GREEN}${SERVER_IP}${NC}"
echo ""

# Solicitar dominio
read -p "  Ingresa tu dominio: " DOMAIN
if [[ -z "$DOMAIN" ]]; then
    echo -e "\n${RED}[ERROR] Se requiere un dominio${NC}"
    exit 1
fi

# Solicitar email para Let's Encrypt
echo ""
read -p "  Email para notificaciones SSL: " EMAIL
if [[ -z "$EMAIL" ]]; then
    echo -e "${YELLOW}  [WARN] Sin email, usando admin@domain${NC}"
    EMAIL="admin@${DOMAIN}"
fi

# Solicitar nombre de organización (opcional)
echo ""
read -p "  Nombre de organización (opcional, ENTER para omitir): " ORG_NAME

echo ""
echo -e "${YELLOW}[*] Verificando configuración DNS...${NC}"
sleep 2

# Verificar DNS
DOMAIN_IP=$(dig +short "$DOMAIN" 2>/dev/null | head -n1)

if [[ "$DOMAIN_IP" != "$SERVER_IP" ]]; then
    echo -e "\n${RED}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  ERROR: El dominio NO apunta a este servidor     ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  Dominio: ${DOMAIN}"
    echo -e "  Apunta a: ${RED}${DOMAIN_IP}${NC}"
    echo -e "  Debe apuntar a: ${GREEN}${SERVER_IP}${NC}"
    echo ""
    echo -e "${YELLOW}SOLUCIÓN:${NC}"
    echo "  1. Ve al panel de tu dominio"
    echo "  2. Crea registro DNS tipo A"
    echo "  3. Apunta a: ${SERVER_IP}"
    echo "  4. Espera 5-10 minutos"
    echo "  5. Ejecuta este script nuevamente"
    echo ""
    exit 1
fi

echo -e "${GREEN}[OK] Dominio verificado: ${DOMAIN} → ${SERVER_IP}${NC}"

mkdir -p /etc/oxgi
echo "$DOMAIN" > /etc/oxgi/domain.conf
echo "$EMAIL" > /etc/oxgi/admin_email

read -p "  ¿Continuar instalación? (s/n): " CONFIRM
[[ "$CONFIRM" != "s" && "$CONFIRM" != "S" ]] && exit 1

clear

echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║      ${GREEN}INICIANDO INSTALACIÓN AUTOMÁTICA...${NC}${CYAN}       ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
echo ""

# ═══════════════════════════════════════════════════════════════
# INSTALACIÓN DE SERVICIOS BÁSICOS
# ═══════════════════════════════════════════════════════════════

echo -e "${YELLOW}[1/10] Actualizando sistema...${NC}"
apt update -y > /dev/null 2>&1
apt upgrade -y > /dev/null 2>&1
apt install -y curl wget sudo cron ufw nginx python3 jq bc stunnel4 \
    build-essential cmake openssl libssl-dev websockify dropbear \
    fail2ban vnstat unzip git dnsutils certbot python3-certbot-nginx > /dev/null 2>&1

echo -e "${YELLOW}[2/10] Creando Swap RAM (1GB)...${NC}"
fallocate -l 1G /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=1024 > /dev/null 2>&1
chmod 600 /swapfile
mkswap /swapfile > /dev/null 2>&1
swapon /swapfile > /dev/null 2>&1
echo '/swapfile none swap sw 0 0' >> /etc/fstab

echo -e "${YELLOW}[3/10] Optimizando red (BBR)...${NC}"
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p > /dev/null 2>&1

echo -e "${YELLOW}[4/10] Configurando Firewall...${NC}"
ufw --force reset > /dev/null 2>&1
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 109/tcp
ufw allow 7300/udp
echo "y" | ufw enable > /dev/null 2>&1

echo -e "${YELLOW}[5/10] Instalando Fail2Ban...${NC}"
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
maxretry = 5
[sshd]
enabled = true
port = 22,109
EOF
systemctl enable --now fail2ban > /dev/null 2>&1

echo -e "${YELLOW}[6/10] Configurando Dropbear (109)...${NC}"
sed -i 's/NO_START=1/NO_START=0/' /etc/default/dropbear
sed -i 's/DROPBEAR_PORT=22/DROPBEAR_PORT=109/' /etc/default/dropbear
systemctl enable --now dropbear > /dev/null 2>&1

echo -e "${YELLOW}[7/10] Instalando BadVPN (7300)...${NC}"
mkdir -p /tmp/badvpn && cd /tmp/badvpn
git clone https://github.com/ambrop72/badvpn.git . > /dev/null 2>&1
mkdir build && cd build
cmake .. -DBUILD_NOTHING_BY_DEFAULT=ON -DBUILD_UDPGW=ON > /dev/null 2>&1
make > /dev/null 2>&1
cp udpgw/badvpn-udpgw /usr/bin/

cat > /etc/systemd/system/badvpn.service << EOF
[Unit]
Description=BadVPN UDPGW
[Service]
ExecStart=/usr/bin/badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 1000
Restart=on-failure
[Install]
WantedBy=multi-user.target
EOF
systemctl enable --now badvpn > /dev/null 2>&1

echo -e "${YELLOW}[8/10] Instalando Xray Core...${NC}"
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install > /dev/null 2>&1
mkdir -p /etc/xray

UUID=$(cat /proc/sys/kernel/random/uuid)
echo "$UUID" > /etc/oxgi/xray_uuid

cat > /etc/xray/config.json << EOF
{
  "log": {"loglevel": "warning"},
  "inbounds": [
    {
      "port": 10000,
      "protocol": "vless",
      "settings": {
        "clients": [{"id": "${UUID}", "level": 0}],
        "decryption": "none"
      },
      "streamSettings": {"network": "ws", "wsSettings": {"path": "/vless"}}
    },
    {
      "port": 10001,
      "protocol": "vmess",
      "settings": {
        "clients": [{"id": "${UUID}", "level": 0}]
      },
      "streamSettings": {"network": "ws", "wsSettings": {"path": "/vmess"}}
    },
    {
      "port": 10002,
      "protocol": "trojan",
      "settings": {
        "clients": [{"password": "${UUID}", "level": 0}]
      },
      "streamSettings": {"network": "ws", "wsSettings": {"path": "/trojan"}}
    }
  ],
  "outbounds": [{"protocol": "freedom"}]
}
EOF
systemctl enable --now xray > /dev/null 2>&1

# ═══════════════════════════════════════════════════════════════
# PASO 9: INSTALAR CERTIFICADO SSL REAL CON CERTBOT
# ══════════════════════════════════════════════════════════════

echo -e "${YELLOW}[9/10] ═══════════════════════════════════════${NC}"
echo -e "${YELLOW}      INSTALANDO CERTIFICADO SSL REAL${NC}"
echo -e "${YELLOW}      Let's Encrypt + Certbot${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${CYAN}Datos del certificado:${NC}"
echo -e "  • Dominio: ${GREEN}${DOMAIN}${NC}"
echo -e "  • Email: ${GREEN}${EMAIL}${NC}"
[[ -n "$ORG_NAME" ]] && echo -e "  • Organización: ${GREEN}${ORG_NAME}${NC}"
echo ""
echo -e "  ${YELLOW}[*] Deteniendo Nginx temporalmente...${NC}"
systemctl stop nginx > /dev/null 2>&1

echo -e "  ${YELLOW}[*] Solicitando certificado a Let's Encrypt...${NC}"
echo -e "  ${CYAN}(Esto puede tardar 1-2 minutos)${NC}"
echo ""

# INSTALAR CERTIFICADO SSL REAL CON CERTBOT
certbot certonly \
    --standalone \
    -d "$DOMAIN" \
    --email "$EMAIL" \
    --non-interactive \
    --agree-tos \
    --force-renewal \
    2>&1 | tee /tmp/certbot.log

CERTBOT_EXIT=${PIPESTATUS[0]}

if [[ $CERTBOT_EXIT -ne 0 ]]; then
    echo -e "\n${RED}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  ERROR: FALLÓ LA INSTALACIÓN DEL CERTIFICADO SSL   ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Verifica:${NC}"
    echo "  1. El dominio ${DOMAIN} apunta a ${SERVER_IP}"
    echo "  2. El puerto 80 está libre"
    echo "  3. El email ${EMAIL} es válido"
    echo ""
    echo -e "${CYAN}Log de error:${NC}"
    cat /tmp/certbot.log
    echo ""
    exit 1
fi

# VERIFICAR que el certificado se instaló
SSL_CERT="/etc/letsencrypt/live/${DOMAIN}/fullchain.pem"
SSL_KEY="/etc/letsencrypt/live/${DOMAIN}/privkey.pem"

if [[ ! -f "$SSL_CERT" ]] || [[ ! -f "$SSL_KEY" ]]; then
    echo -e "\n${RED}[ERROR] Los archivos del certificado no existen${NC}"
    exit 1
fi

# Obtener información del certificado REAL
CERT_ISSUER=$(openssl x509 -in "$SSL_CERT" -noout -issuer | sed 's/issuer=//')
CERT_EXPIRY=$(openssl x509 -in "$SSL_CERT" -noout -enddate | cut -d= -f2)
CERT_SUBJECT=$(openssl x509 -in "$SSL_CERT" -noout -subject | sed 's/subject=//')

echo ""
echo -e "  ${GREEN}╔══════════════════════════════════════════════╗${NC}"
echo -e "  ${GREEN}║  ✓ CERTIFICADO SSL REAL INSTALADO${NC}${GREEN}          ║${NC}"
echo -e "  ${GREEN}╚══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${CYAN}Detalles del certificado:${NC}"
echo -e "  • Emisor: ${GREEN}${CERT_ISSUER}${NC}"
echo -e "  • Dominio: ${GREEN}${CERT_SUBJECT}${NC}"
echo -e "  • Válido hasta: ${GREEN}${CERT_EXPIRY}${NC}"
echo -e "  • Ubicación: ${GREEN}/etc/letsencrypt/live/${DOMAIN}/${NC}"
echo ""

# ═══════════════════════════════════════════════════════════════
# PASO 10: CONFIGURAR NGINX CON SSL REAL
# ══════════════════════════════════════════════════════════════

echo -e "${YELLOW}[10/10] Configurando Nginx con SSL REAL...${NC}"

rm -f /etc/nginx/sites-enabled/default

cat > /etc/nginx/sites-available/oxgi << EOF
# HTTP - Puerto 80 (WebSocket Non-TLS)
server {
    listen 80;
    server_name ${DOMAIN} _;
    
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
    
    location /vless {
        proxy_pass http://127.0.0.1:10000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_buffering off;
    }
    
    location /vmess {
        proxy_pass http://127.0.0.1:10001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_buffering off;
    }
    
    location /trojan {
        proxy_pass http://127.0.0.1:10002;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_buffering off;
    }
}

# HTTPS - Puerto 443 (WebSocket TLS con SSL REAL)
server {
    listen 443 ssl http2;
    server_name ${DOMAIN} _;
    
    # CERTIFICADO SSL REAL DE LET'S ENCRYPT
    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
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
    
    location /vless {
        proxy_pass http://127.0.0.1:10000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_buffering off;
    }
    
    location /vmess {
        proxy_pass http://127.0.0.1:10001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_buffering off;
    }
    
    location /trojan {
        proxy_pass http://127.0.0.1:10002;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_buffering off;
    }
}
EOF

ln -sf /etc/nginx/sites-available/oxgi /etc/nginx/sites-enabled/

# Websockify
cat > /etc/systemd/system/websockify.service << 'EOF'
[Unit]
Description=Websockify SSH Bridge
[Service]
Type=simple
ExecStart=/usr/bin/websockify 2090 127.0.0.1:22
Restart=on-failure
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now websockify nginx > /dev/null 2>&1

# Renovación automática SSL
echo "0 3 * * * certbot renew --quiet && systemctl reload nginx" | crontab -

# Instalar panel OXGI
INSTALL_DIR="/usr/local/oxgi"
rm -rf "$INSTALL_DIR"
git clone -b main https://github.com/gitechcode-star/oxgi-vps-script.git "$INSTALL_DIR" > /dev/null 2>&1
chmod +x "$INSTALL_DIR"/*.sh "$INSTALL_DIR"/modules/*.sh
ln -sf "$INSTALL_DIR"/oxgi.sh /usr/local/bin/oxgi

# Auto-clean script
cat > /etc/oxgi/auto_clean.sh << 'CLEANEOF'
#!/bin/bash
DB="/etc/oxgi/ssh_users.db"
[[ ! -f "$DB" ]] && exit 0
now=$(date +%s); tmp="${DB}.tmp"; > "$tmp"
while IFS='|' read -r user pass dev created exp auto_del; do
    [[ -n "$user" ]] && { [[ $now -gt $auto_del ]] && userdel -r "$user" 2>/dev/null || echo "$user|$pass|$dev|$created|$exp|$auto_del" >> "$tmp"; }
done < "$DB"
mv "$tmp" "$DB"
while IFS='|' read -r user pass max_dev created exp auto_del; do
    sessions=$(who | grep "^$user " | wc -l)
    [[ $sessions -gt $max_dev ]] && pkill -9 -u "$user"
done < "$DB"
CLEANEOF
chmod +x /etc/oxgi/auto_clean.sh

(crontab -l 2>/dev/null; echo "0 5 * * * /sbin/reboot") | crontab -
(crontab -l 2>/dev/null; echo "0 * * * * /bin/bash /etc/oxgi/auto_clean.sh") | crontab -

clear

# ═══════════════════════════════════════════════════════════════
# RESUMEN FINAL
# ═══════════════════════════════════════════════════════════════

echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     ${BOLD}OXGI VPS - INSTALACIÓN COMPLETADA${NC}${GREEN}           ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}PORT:${NC}"
echo -e "${CYAN}Port & Service${NC}"
echo -e "${CYAN}=========================${NC}"
echo -e "OpenSSH           : ${GREEN}22${NC}"
echo -e "WebSocket TLS     : ${GREEN}443${NC}"
echo -e "WebSocket NonTLS  : ${GREEN}80${NC}"
echo -e "UDP Custom        : ${GREEN}1-65535${NC}"
echo -e "BadVPN/UDPWG      : ${GREEN}7300${NC}"
echo -e "Dropbear SSH      : ${GREEN}109${NC}"
echo -e "${CYAN}=========================${NC}"
echo ""
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ CERTIFICADO SSL REAL INSTALADO${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "Dominio       : ${GREEN}${DOMAIN}${NC}"
echo -e "Email         : ${GREEN}${EMAIL}${NC}"
[[ -n "$ORG_NAME" ]] && echo -e "Organización: ${GREEN}${ORG_NAME}${NC}"
echo -e "Emisor        : ${GREEN}${CERT_ISSUER}${NC}"
echo -e "Válido hasta  : ${GREEN}${CERT_EXPIRY}${NC}"
echo -e "Auto-Renew    : ${GREEN}Activado (diario 3 AM)${NC}"
echo ""
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}HTTP CUSTOM / INJECTOR${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "Host      : ${GREEN}${DOMAIN}${NC}"
echo -e "Port TLS  : ${GREEN}443${NC} ${GREEN}✓ SSL REAL${NC}"
echo -e "Port HTTP : ${GREEN}80${NC}"
echo -e "Path      : ${GREEN}/${NC}"
echo ""
echo -e "${GREEN}══════════════════════════════════════════════════${NC}"
echo -e "  Type ${YELLOW}oxgi${NC}${GREEN} to manage your VPS${NC}"
echo -e "${GREEN}══════════════════════════════════════════════════${NC}"
echo ""
