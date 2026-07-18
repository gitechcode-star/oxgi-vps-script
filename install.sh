#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# OXGI VPS SCRIPT v1.0.0
# Compatible with HTTP Custom, Injector, TLS Tunnel
# ══════════════════════════════════════════════════════════════

clear

export DEBIAN_FRONTEND=noninteractive
GREEN='\033[1;32m'; RED='\033[1;31m'; YELLOW='\033[1;33m'; CYAN='\033[1;36m'; NC='\033[0m'; BOLD='\033[1m'

# ══════════════════════════════════════════════════════════════
# HEADER OXGI VPS
# ═══════════════════════════════════════════════════════════════

echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                                                  ║${NC}"
echo -e "${CYAN}║           ${GREEN}${BOLD}OXGI VPS SCRIPT${NC}${CYAN} v1.0.0              ║${NC}"
echo -e "${CYAN}║                                                  ║${NC}"
echo -e "${CYAN}║     ${YELLOW}Auto Install Script for VPS${NC}${CYAN}                 ║${NC}"
echo -e "${CYAN}║                                                  ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
echo ""

# ═══════════════════════════════════════════════════════════════
# SOLICITAR DOMINIO
# ═══════════════════════════════════════════════════════════════

echo -e "${YELLOW}══════════════════════════════════════════════════${NC}"
echo -e "  ${BOLD}CONFIGURACIÓN DE DOMINIO${NC}"
echo -e "${YELLOW}══════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${CYAN}Ingresa tu dominio para SSL (Let's Encrypt)${NC}"
echo -e "  ${YELLOW}Ejemplo: vps.midominio.com${NC}"
echo ""

SERVER_IP=$(curl -s https://api.ipify.org 2>/dev/null || echo "127.0.0.1")
echo -e "  IP del Servidor: ${GREEN}${SERVER_IP}${NC}"
echo ""

read -p "  Dominio: " DOMAIN

if [[ -z "$DOMAIN" ]]; then
    echo -e "${RED}\n[ERROR] Se requiere un dominio para SSL REAL${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}[*] Verificando DNS...${NC}"
sleep 2

DOMAIN_IP=$(dig +short "$DOMAIN" 2>/dev/null | head -n1)

if [[ "$DOMAIN_IP" != "$SERVER_IP" ]]; then
    echo -e "${RED}[ERROR] El dominio no apunta a este servidor${NC}"
    echo -e "  Dominio apunta a: ${DOMAIN_IP}"
    echo -e "  Servidor IP: ${SERVER_IP}"
    exit 1
fi

echo -e "${GREEN}[OK] Dominio verificado correctamente${NC}"
mkdir -p /etc/oxgi
echo "$DOMAIN" > /etc/oxgi/domain.conf

read -p "  ¿Continuar instalación? (s/n): " CONFIRM
[[ "$CONFIRM" != "s" && "$CONFIRM" != "S" ]] && exit 1

clear

echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║      ${GREEN}INICIANDO INSTALACIÓN AUTOMÁTICA...${NC}${CYAN}       ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
echo ""

# ═══════════════════════════════════════════════════════════════
# INSTALACIÓN
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
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
maxretry = 5
[sshd]
enabled = true
port = 22,109
EOF
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

echo -e "${YELLOW}[8/9] Instalando Xray Core...${NC}"
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install > /dev/null 2>&1
mkdir -p /etc/xray

UUID=$(cat /proc/sys/kernel/random/uuid)
echo "$UUID" > /etc/oxgi/xray_uuid

# Configuración Xray para HTTP Custom (WebSocket en 80/443)
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
    },
    {
      "port": 10003,
      "protocol": "vless",
      "settings": {
        "clients": [{"id": "${UUID}", "level": 0}],
        "decryption": "none"
      },
      "streamSettings": {"network": "grpc", "grpcSettings": {"serviceName": "grpc"}}
    }
  ],
  "outbounds": [{"protocol": "freedom"}]
}
EOF
systemctl enable --now xray > /dev/null 2>&1

echo -e "${YELLOW}[9/9] Instalando SSL REAL y configurando Nginx...${NC}"

# Obtener certificado SSL real
systemctl stop nginx
certbot certonly --standalone -d "$DOMAIN" --non-interactive --agree-tos --email admin@"${DOMAIN#*.}" > /dev/null 2>&1

# Configuración Nginx para HTTP Custom / Injector
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
    
    location /grpc {
        proxy_pass http://127.0.0.1:10003;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_buffering off;
    }
}

# HTTPS - Puerto 443 (WebSocket TLS)
server {
    listen 443 ssl http2;
    server_name ${DOMAIN} _;
    
    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    
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
    
    location /grpc {
        proxy_pass http://127.0.0.1:10003;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_buffering off;
    }
}
EOF

ln -sf /etc/nginx/sites-available/oxgi /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Websockify para SSH
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

# Script auto_clean.sh
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
echo -e "${GREEN}║        ${BOLD}OXGI VPS - INSTALACIÓN COMPLETADA${NC}${GREEN}        ║${NC}"
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
echo -e "gRPC              : ${GREEN}443${NC}"
echo -e "${CYAN}=========================${NC}"
echo ""
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}SETTING CLOUDFLARE${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "SSL/TLS              : ${GREEN}FULL${NC}"
echo -e "SSL/TLS Recommender  : ${GREEN}ON${NC}"
echo -e "GRPC                 : ${GREEN}ON${NC}"
echo -e "WEBSOCKET            : ${GREEN}ON${NC}"
echo -e "Always Use HTTPS     : ${RED}OFF${NC}"
echo -e "UNDER ATTACK MODE    : ${RED}OFF${NC}"
echo ""
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}SSL CERTIFICATE${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "Domain    : ${GREEN}${DOMAIN}${NC}"
echo -e "Type      : ${GREEN}Let's Encrypt (REAL)${NC}"
echo -e "Valid     : ${GREEN}90 days (auto-renew)${NC}"
echo ""
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}XRAY CONFIG${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "UUID      : ${GREEN}${UUID}${NC}"
echo -e "VLESS TLS : ${GREEN}vless://${UUID}@${DOMAIN}:443?encryption=none&security=tls&type=ws&path=/vless#OXGI${NC}"
echo -e "VMESS TLS : ${GREEN}vmess://${UUID}@${DOMAIN}:443?security=tls&type=ws&path=/vmess#OXGI${NC}"
echo -e "TROJAN    : ${GREEN}trojan://${UUID}@${DOMAIN}:443?security=tls&type=ws&path=/trojan#OXGI${NC}"
echo -e "gRPC      : ${GREEN}vless://${UUID}@${DOMAIN}:443?encryption=none&security=tls&type=grpc&serviceName=grpc#OXGI${NC}"
echo ""
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}HTTP CUSTOM / INJECTOR${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "Host      : ${GREEN}${DOMAIN}${NC}"
echo -e "Port TLS  : ${GREEN}443${NC}"
echo -e "Port HTTP : ${GREEN}80${NC}"
echo -e "Path      : ${GREEN}/${NC} (root)"
echo -e ""
echo -e "${GREEN}══════════════════════════════════════════════════${NC}"
echo -e "  Type ${YELLOW}oxgi${NC}${GREEN} to manage your VPS${NC}"
echo -e "${GREEN}══════════════════════════════════════════════════${NC}"
echo ""
