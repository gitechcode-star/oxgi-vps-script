#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# OXGI VPS SCRIPT v1.1.0 - CORREGIDO
# SSL REAL con Let's Encrypt (Certbot)
# WebSocket SSH funcional con Nginx + Websockify
# ══════════════════════════════════════════════════════════════

set -e

clear

export DEBIAN_FRONTEND=noninteractive
GREEN='\033[1;32m'; RED='\033[1;31m'; YELLOW='\033[1;33m'; CYAN='\033[1;36m'; NC='\033[0m'; BOLD='\033[1m'

echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║           ${GREEN}${BOLD}OXGI VPS SCRIPT${NC}${CYAN} v1.1.0 (FIXED)       ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
echo ""

# ═══════════════════════════════════════════════════════════════
# SOLICITAR DOMINIO
# ═══════════════════════════════════════════════════════════════

echo -e "${YELLOW}══════════════════════════════════════════════════${NC}"
echo -e "  ${BOLD}CONFIGURACIÓN DE DOMINIO${NC}"
echo -e "${YELLOW}══════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${RED}REQUISITO:${NC} Se necesita un dominio para SSL REAL"
echo -e "  ${CYAN}Certificado: Let's Encrypt (Certbot)${NC}"
echo ""

SERVER_IP=$(curl -s https://api.ipify.org 2>/dev/null || echo "127.0.0.1")
echo -e "  IP del Servidor: ${GREEN}${SERVER_IP}${NC}"
echo ""

read -p "  Ingresa tu dominio: " DOMAIN

if [[ -z "$DOMAIN" ]]; then
    echo -e "\n${RED}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  ERROR: DOMINIO REQUERIDO PARA SSL REAL          ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}INSTRUCCIONES:${NC}"
    echo "  1. Registra un dominio (Namecheap, Freenom, etc.)"
    echo "  2. Crea registro DNS tipo A apuntando a: ${SERVER_IP}"
    echo "  3. Espera 5-10 minutos"
    echo "  4. Ejecuta este script nuevamente"
    echo ""
    exit 1
fi

# ══════════════════════════════════════════════════════════════
# VERIFICAR DNS
# ═══════════════════════════════════════════════════════════════

echo ""
echo -e "${YELLOW}[*] Verificando que el dominio apunte a este servidor...${NC}"
sleep 2

DOMAIN_IP=$(dig +short "$DOMAIN" 2>/dev/null | head -n1)

if [[ -z "$DOMAIN_IP" ]]; then
    echo -e "${RED}[ERROR] No se pudo resolver el dominio: ${DOMAIN}${NC}"
    exit 1
fi

echo -e "  • IP del dominio (${DOMAIN}): ${CYAN}${DOMAIN_IP}${NC}"
echo -e "  • IP del servidor: ${CYAN}${SERVER_IP}${NC}"

if [[ "$DOMAIN_IP" != "$SERVER_IP" ]]; then
    echo -e "\n${RED}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  ERROR: EL DOMINIO NO APUNTA A ESTE SERVIDOR     ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  El dominio ${CYAN}${DOMAIN}${NC} apunta a ${RED}${DOMAIN_IP}${NC}"
    echo -e "  pero debe apuntar a ${GREEN}${SERVER_IP}${NC}"
    echo ""
    echo -e "${YELLOW}SOLUCIÓN:${NC}"
    echo "  1. Ve al panel de tu dominio"
    echo "  2. Crea/edita registro DNS tipo A"
    echo "  3. Apunta a: ${SERVER_IP}"
    echo "  4. Espera 5-10 minutos"
    echo "  5. Ejecuta este script nuevamente"
    echo ""
    exit 1
fi

echo -e "\n${GREEN}[OK] El dominio apunta correctamente${NC}"
mkdir -p /etc/oxgi
echo "$DOMAIN" > /etc/oxgi/domain.conf

read -p "  ¿Continuar con la instalación? (s/n): " CONFIRM
[[ "$CONFIRM" != "s" && "$CONFIRM" != "S" ]] && { echo "Cancelado."; exit 1; }

clear

echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║      ${GREEN}INICIANDO INSTALACIÓN AUTOMÁTICA...${NC}${CYAN}       ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
echo ""

# ═══════════════════════════════════════════════════════════════
# INSTALACIÓN DE SERVICIOS
# ═══════════════════════════════════════════════════════════════

echo -e "${YELLOW}[1/9] Actualizando sistema...${NC}"
apt update -y > /dev/null 2>&1
apt upgrade -y > /dev/null 2>&1
apt install -y curl wget sudo cron ufw nginx python3 jq bc stunnel4 \
    build-essential cmake openssl libssl-dev websockify dropbear \
    fail2ban vnstat unzip git dnsutils certbot python3-certbot-nginx > /dev/null 2>&1

echo -e "${YELLOW}[2/9] Creando Swap RAM (1GB)...${NC}"
fallocate -l 1G /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=1024 > /dev/null 2>&1
chmod 600 /swapfile
mkswap /swapfile > /dev/null 2>&1
swapon /swapfile > /dev/null 2>&1
echo '/swapfile none swap sw 0 0' >> /etc/fstab

echo -e "${YELLOW}[3/9] Optimizando red (BBR)...${NC}"
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p > /dev/null 2>&1

echo -e "${YELLOW}[4/9] Configurando Firewall...${NC}"
ufw --force reset > /dev/null 2>&1
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 109/tcp
ufw allow 7300/udp
echo "y" | ufw enable > /dev/null 2>&1

echo -e "${YELLOW}[5/9] Instalando Fail2Ban...${NC}"
cat > /etc/fail2ban/jail.local << 'JAILEOF'
[DEFAULT]
bantime = 3600
maxretry = 5
[sshd]
enabled = true
port = 22,109
JAILEOF
systemctl enable --now fail2ban > /dev/null 2>&1

echo -e "${YELLOW}[6/9] Configurando Dropbear (109)...${NC}"
sed -i 's/NO_START=1/NO_START=0/' /etc/default/dropbear
sed -i 's/DROPBEAR_PORT=22/DROPBEAR_PORT=109/' /etc/default/dropbear
systemctl enable --now dropbear > /dev/null 2>&1

echo -e "${YELLOW}[7/9] Instalando BadVPN (7300)...${NC}"
mkdir -p /tmp/badvpn && cd /tmp/badvpn
git clone https://github.com/ambrop72/badvpn.git . > /dev/null 2>&1
mkdir build && cd build
cmake .. -DBUILD_NOTHING_BY_DEFAULT=ON -DBUILD_UDPGW=ON > /dev/null 2>&1
make > /dev/null 2>&1
cp udpgw/badvpn-udpgw /usr/bin/

cat > /etc/systemd/system/badvpn.service << 'BADEOF'
[Unit]
Description=BadVPN UDPGW
[Service]
ExecStart=/usr/bin/badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 1000
Restart=on-failure
[Install]
WantedBy=multi-user.target
BADEOF
systemctl enable --now badvpn > /dev/null 2>&1

echo -e "${YELLOW}[8/9] Instalando Xray Core...${NC}"
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install > /dev/null 2>&1
mkdir -p /etc/xray

UUID=$(cat /proc/sys/kernel/random/uuid)
echo "$UUID" > /etc/oxgi/xray_uuid

cat > /etc/xray/config.json << XRAYEOF
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
XRAYEOF
systemctl enable --now xray > /dev/null 2>&1

# ═══════════════════════════════════════════════════════════════
# PASO 9: INSTALAR CERTIFICADO SSL REAL CON CERTBOT
# ═══════════════════════════════════════════════════════════════

echo -e "${YELLOW}[9/9] Instalando CERTIFICADO SSL REAL con Certbot...${NC}"
echo -e "  ${CYAN}Autoridad: Let's Encrypt${NC}"
echo -e "  ${CYAN}Dominio: ${DOMAIN}${NC}"
sleep 2

# Detener Nginx para que Certbot use el puerto 80
systemctl stop nginx > /dev/null 2>&1

# Solicitar certificado SSL REAL con Certbot
echo -e "  ${YELLOW}[*] Solicitando certificado a Let's Encrypt...${NC}"
certbot certonly --standalone \
    -d "$DOMAIN" \
    --non-interactive \
    --agree-tos \
    --email admin@"${DOMAIN#*.}" \
    --force-renewal > /dev/null 2>&1

CERTBOT_EXIT=$?

if [[ $CERTBOT_EXIT -ne 0 ]]; then
    echo -e "\n${RED}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  ERROR: NO SE PUDO OBTENER EL CERTIFICADO SSL      ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}POSIBLES CAUSAS:${NC}"
    echo "  1. El dominio no apunta correctamente a ${SERVER_IP}"
    echo "  2. El puerto 80 está bloqueado por otro servicio"
    echo "  3. Ya existe un certificado para este dominio"
    echo "  4. Límite de rate limit de Let's Encrypt"
    echo ""
    echo -e "${CYAN}SOLUCIONES:${NC}"
    echo "  • Verifica que el dominio apunte a: ${SERVER_IP}"
    echo "  • Ejecuta: netstat -tlnp | grep :80"
    echo "  • Espera 1 hora si hay rate limit"
    echo ""
    exit 1
fi

# VERIFICAR que el certificado REAL se haya instalado
SSL_CERT="/etc/letsencrypt/live/${DOMAIN}/fullchain.pem"
SSL_KEY="/etc/letsencrypt/live/${DOMAIN}/privkey.pem"

if [[ ! -f "$SSL_CERT" ]] || [[ ! -f "$SSL_KEY" ]]; then
    echo -e "${RED}[ERROR] Los archivos del certificado no existen${NC}"
    exit 1
fi

# Verificar que el certificado sea válido
if ! openssl x509 -in "$SSL_CERT" -noout -dates > /dev/null 2>&1; then
    echo -e "${RED}[ERROR] El certificado SSL no es válido${NC}"
    exit 1
fi

# Obtener información del certificado
CERT_ISSUER=$(openssl x509 -in "$SSL_CERT" -noout -issuer | cut -d= -f2)
CERT_EXPIRY=$(openssl x509 -in "$SSL_CERT" -noout -enddate | cut -d= -f2)

echo -e "  ${GREEN}[OK] Certificado SSL REAL instalado exitosamente${NC}"
echo -e "  • Emisor: ${CYAN}${CERT_ISSUER}${NC}"
echo -e "  • Válido hasta: ${CYAN}${CERT_EXPIRY}${NC}"
echo -e "  • Ubicación: ${GREEN}/etc/letsencrypt/live/${DOMAIN}/${NC}"

# ═══════════════════════════════════════════════════════════════
# CONFIGURAR NGINX CON CERTIFICADO SSL REAL - CORREGIDO
# ═══════════════════════════════════════════════════════════════

rm -f /etc/nginx/sites-enabled/default
rm -f /etc/nginx/sites-enabled/oxgi
rm -f /etc/nginx/sites-available/oxgi

# ============================================================
# CONFIG NGINX CORREGIDA - Variables escapadas con \
# ============================================================
cat > /etc/nginx/sites-available/oxgi << 'NGINXEOF'
# HTTP - Puerto 80 (Redirige a HTTPS + ACME challenge)
server {
    listen 80;
    listen [::]:80;
    server_name _;

    # ACME challenge para renovación automática
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
        allow all;
    }

    location / {
        return 301 https://$host$request_uri;
    }
}

# HTTPS - Puerto 443 (WebSocket TLS con SSL REAL)
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name _;

    # Certificados SSL (se reemplazan con sed después)
    ssl_certificate /etc/letsencrypt/live/DOMAIN_PLACEHOLDER/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/DOMAIN_PLACEHOLDER/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;

    # Desactivar buffering para WebSocket
    proxy_buffering off;
    proxy_request_buffering off;

    # ============================================================
    # WebSocket SSH (HTTP Custom / Injector)
    # ============================================================
    location / {
        proxy_pass http://127.0.0.1:2090;
        proxy_http_version 1.1;

        # Headers CRÍTICOS para WebSocket - Escapados para Nginx
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Timeouts largos para conexiones persistentes
        proxy_connect_timeout 86400s;
        proxy_send_timeout 86400s;
        proxy_read_timeout 86400s;

        # Desactivar caché
        proxy_cache_bypass $http_upgrade;
    }

    # ============================================================
    # VLESS WebSocket
    # ============================================================
    location /vless {
        proxy_pass http://127.0.0.1:10000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_buffering off;
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }

    # ============================================================
    # VMESS WebSocket
    # ============================================================
    location /vmess {
        proxy_pass http://127.0.0.1:10001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_buffering off;
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }

    # ============================================================
    # TROJAN WebSocket
    # ============================================================
    location /trojan {
        proxy_pass http://127.0.0.1:10002;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_buffering off;
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }

    # Health check
    location /health {
        access_log off;
        return 200 "OK\n";
        add_header Content-Type text/plain;
    }
}
NGINXEOF

# Reemplazar el placeholder del dominio con el dominio real
sed -i "s|DOMAIN_PLACEHOLDER|${DOMAIN}|g" /etc/nginx/sites-available/oxgi

ln -sf /etc/nginx/sites-available/oxgi /etc/nginx/sites-enabled/oxgi

# ============================================================
# WEBSOCKIFY SERVICE CORREGIDO
# ============================================================
cat > /etc/systemd/system/websockify.service << 'WSEOF'
[Unit]
Description=Websockify SSH Bridge
After=network.target
Wants=network.target

[Service]
Type=simple
ExecStart=/usr/bin/websockify --verbose --log-file /var/log/websockify.log 2090 127.0.0.1:22
Restart=on-failure
RestartSec=5
StandardOutput=append:/var/log/websockify.log
StandardError=append:/var/log/websockify.log

[Install]
WantedBy=multi-user.target
WSEOF

# Crear directorio para logs
mkdir -p /var/log
touch /var/log/websockify.log

# ============================================================
# VERIFICAR Y REINICIAR SERVICIOS
# ============================================================
echo -e "${YELLOW}[*] Verificando configuración de Nginx...${NC}"
nginx -t
if [[ $? -ne 0 ]]; then
    echo -e "${RED}[ERROR] Configuración de Nginx inválida${NC}"
    exit 1
fi

systemctl daemon-reload
systemctl enable --now websockify nginx > /dev/null 2>&1

# Verificar que websockify esté escuchando
sleep 2
if ! ss -tlnp | grep -q ':2090'; then
    echo -e "${YELLOW}[!] Websockify no respondió inmediatamente, reiniciando...${NC}"
    systemctl restart websockify
    sleep 2
fi

# Renovación automática
echo "0 3 * * * certbot renew --quiet --deploy-hook 'systemctl reload nginx'" | crontab -

# Instalar panel
INSTALL_DIR="/usr/local/oxgi"
rm -rf "$INSTALL_DIR"
git clone -b main https://github.com/gitechcode-star/oxgi-vps-script.git "$INSTALL_DIR" > /dev/null 2>&1
chmod +x "$INSTALL_DIR"/*.sh "$INSTALL_DIR"/modules/*.sh 2>/dev/null || true
ln -sf "$INSTALL_DIR"/oxgi.sh /usr/local/bin/oxgi 2>/dev/null || true

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

echo -e "${GREEN}══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║        ${BOLD}OXGI VPS - INSTALACIÓN COMPLETADA${NC}${GREEN}        ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}PORTS & SERVICES:${NC}"
echo -e "${CYAN}=========================${NC}"
echo -e "OpenSSH           : ${GREEN}22${NC}"
echo -e "WebSocket TLS     : ${GREEN}443${NC}"
echo -e "WebSocket NonTLS  : ${GREEN}80 (redirige a 443)${NC}"
echo -e "UDP Custom        : ${GREEN}1-65535${NC}"
echo -e "BadVPN/UDPWG      : ${GREEN}7300${NC}"
echo -e "Dropbear SSH      : ${GREEN}109${NC}"
echo -e "gRPC              : ${GREEN}443${NC}"
echo -e "${CYAN}=========================${NC}"
echo ""
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}CLOUDFLARE SETTINGS${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "SSL/TLS              : ${GREEN}FULL${NC}"
echo -e "SSL/TLS Recommender  : ${GREEN}ON${NC}"
echo -e "GRPC                 : ${GREEN}ON${NC}"
echo -e "WEBSOCKET            : ${GREEN}ON${NC}"
echo -e "Always Use HTTPS     : ${RED}OFF${NC}"
echo -e "UNDER ATTACK MODE    : ${RED}OFF${NC}"
echo ""
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}SSL CERTIFICATE (REAL - LET'S ENCRYPT)${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "Domain     : ${GREEN}${DOMAIN}${NC}"
echo -e "Issuer     : ${GREEN}${CERT_ISSUER}${NC}"
echo -e "Valid Until: ${GREEN}${CERT_EXPIRY}${NC}"
echo -e "Auto-Renew : ${GREEN}Enabled (daily at 3 AM)${NC}"
echo -e "Location   : ${GREEN}/etc/letsencrypt/live/${DOMAIN}/${NC}"
echo ""
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}XRAY CONFIG${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "UUID      : ${GREEN}${UUID}${NC}"
echo -e "VLESS TLS : ${GREEN}vless://${UUID}@${DOMAIN}:443?encryption=none&security=tls&type=ws&path=/vless#OXGI${NC}"
echo -e "VMESS TLS : ${GREEN}vmess://${UUID}@${DOMAIN}:443?security=tls&type=ws&path=/vmess#OXGI${NC}"
echo -e "TROJAN    : ${GREEN}trojan://${UUID}@${DOMAIN}:443?security=tls&type=ws&path=/trojan#OXGI${NC}"
echo ""
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}HTTP CUSTOM / INJECTOR (WebSocket SSH)${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "Host      : ${GREEN}${DOMAIN}${NC}"
echo -e "Port      : ${GREEN}443${NC}"
echo -e "Path      : ${GREEN}/${NC}"
echo -e "SSL/TLS   : ${GREEN}Activado${NC}"
echo -e "SNI       : ${GREEN}${DOMAIN}${NC}"
echo ""
echo -e "${GREEN}══════════════════════════════════════════════════${NC}"
echo -e "  Type ${YELLOW}oxgi${NC}${GREEN} to manage your VPS${NC}"
echo -e "${GREEN}══════════════════════════════════════════════════${NC}"
echo ""
