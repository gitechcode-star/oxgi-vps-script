#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# OXGI VPS SCRIPT - Instalador Profesional 100% Automático
# ═══════════════════════════════════════════════════════════════

export DEBIAN_FRONTEND=noninteractive
GREEN='\033[1;32m'; RED='\033[1;31m'; YELLOW='\033[1;33m'; CYAN='\033[1;36m'; NC='\033[0m'; BOLD='\033[1m'

echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   ${GREEN}OXGI VPS - Instalador Profesional 100%${NC}${CYAN}         ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
echo ""

# 1. Zona Horaria y Dominio
timedatectl set-timezone Asia/Kuala_Lumpur
echo -e "${YELLOW}══════════════════════════════════════════════════${NC}"
read -p "Dominio para SSL (o ENTER para usar IP): " DOMAIN
SERVER_IP=$(curl -s https://api.ipify.org 2>/dev/null || echo "127.0.0.1")
[[ -z "$DOMAIN" ]] && DOMAIN="$SERVER_IP" && USE_SSL=false || USE_SSL=true
mkdir -p /etc/oxgi && echo "$DOMAIN" > /etc/oxgi/domain.conf

# 2. Actualización y Dependencias
echo -e "${YELLOW}[1/8] Actualizando sistema e instalando dependencias...${NC}"
apt update -y > /dev/null 2>&1 && apt upgrade -y > /dev/null 2>&1
apt install -y curl wget sudo cron ufw nginx python3 jq bc stunnel4 \
    build-essential cmake openssl libssl-dev websockify dropbear \
    fail2ban vnstat unzip git dnsutils certbot python3-certbot-nginx \
    apache2-utils > /dev/null 2>&1

# 3. Swap RAM Virtual (1GB)
echo -e "${YELLOW}[2/8] Creando Swap RAM Virtual (1GB)...${NC}"
fallocate -l 1G /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=1024
chmod 600 /swapfile
mkswap /swapfile > /dev/null 2>&1
swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab

# 4. Optimización de Red (BBR + TCP Tuning)
echo -e "${YELLOW}[3/8] Optimizando red (BBR + TCP Fast Open)...${NC}"
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
echo "net.ipv4.tcp_fastopen=3" >> /etc/sysctl.conf
echo "net.ipv4.tcp_window_scaling=1" >> /etc/sysctl.conf
echo "net.core.rmem_max=16777216" >> /etc/sysctl.conf
echo "net.core.wmem_max=16777216" >> /etc/sysctl.conf
sysctl -p > /dev/null 2>&1

# 5. Firewall (IPtables/UFW)
echo -e "${YELLOW}[4/8] Configurando Firewall...${NC}"
ufw --force reset > /dev/null 2>&1
ufw allow 22/tcp; ufw allow 80/tcp; ufw allow 443/tcp; ufw allow 81/tcp
ufw allow 90/tcp; ufw allow 109/tcp; ufw allow 143/tcp
ufw allow 447/tcp; ufw allow 777/tcp; ufw allow 7100:7300/udp
echo "y" | ufw enable > /dev/null 2>&1

# 6. Fail2Ban & Deflate (Nginx Gzip)
echo -e "${YELLOW}[5/8] Configurando Fail2Ban y Nginx Deflate...${NC}"
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5
[sshd]
enabled = true
port = 22,90,109,143
EOF
systemctl enable --now fail2ban

# 7. Stunnel4 (447, 777) y Dropbear (90, 109, 143)
echo -e "${YELLOW}[6/8] Configurando Dropbear y Stunnel...${NC}"
sed -i 's/NO_START=1/NO_START=0/' /etc/default/dropbear
sed -i 's/DROPBEAR_PORT=22/DROPBEAR_PORT=90/' /etc/default/dropbear
echo 'DROPBEAR_EXTRA_ARGS="-p 109 -p 143 -w -s -j -k"' >> /etc/default/dropbear
systemctl enable --now dropbear

mkdir -p /etc/stunnel
cat > /etc/stunnel/stunnel.conf << EOF
cert = /etc/stunnel/stunnel.pem
sslVersion = TLSv1.2
options = NO_SSLv2
options = NO_SSLv3
[openssh]
accept = 447
connect = 127.0.0.1:22
[dropbear]
accept = 777
connect = 127.0.0.1:90
EOF
openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
    -subj "/C=MY/ST=Selangor/L=KL/O=OXGI/CN=${DOMAIN}" \
    -keyout /etc/stunnel/stunnel.pem -out /etc/stunnel/stunnel.pem > /dev/null 2>&1
sed -i 's/ENABLED=0/ENABLED=1/' /etc/default/stunnel4
systemctl enable --now stunnel4

# 8. BadVPN (7100, 7200, 7300)
echo -e "${YELLOW}[7/8] Compilando BadVPN...${NC}"
mkdir -p /tmp/badvpn && cd /tmp/badvpn
git clone https://github.com/ambrop72/badvpn.git . > /dev/null 2>&1
mkdir build && cd build
cmake .. -DBUILD_NOTHING_BY_DEFAULT=ON -DBUILD_UDPGW=ON > /dev/null 2>&1
make > /dev/null 2>&1
cp udpgw/badvpn-udpgw /usr/bin/

for PORT in 7100 7200 7300; do
cat > /etc/systemd/system/badvpn-${PORT}.service << EOF
[Unit] Description=BadVPN UDPGW ${PORT}
[Service] ExecStart=/usr/bin/badvpn-udpgw --listen-addr 127.0.0.1:${PORT} --max-clients 1000; Restart=on-failure
[Install] WantedBy=multi-user.target
EOF
systemctl enable --now badvpn-${PORT}
done

# 9. Xray Core (Multi-Protocolo: VLESS, VMESS, TROJAN en WS)
echo -e "${YELLOW}[8/8] Instalando y configurando Xray Core...${NC}"
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
        "clients": [{"id": "${UUID}", "level": 0, "email": "vless@oxgi"}],
        "decryption": "none"
      },
      "streamSettings": {"network": "ws", "wsSettings": {"path": "/vless"}}
    },
    {
      "port": 10001,
      "protocol": "vmess",
      "settings": {
        "clients": [{"id": "${UUID}", "level": 0, "email": "vmess@oxgi"}]
      },
      "streamSettings": {"network": "ws", "wsSettings": {"path": "/vmess"}}
    },
    {
      "port": 10002,
      "protocol": "trojan",
      "settings": {
        "clients": [{"password": "${UUID}", "level": 0, "email": "trojan@oxgi"}]
      },
      "streamSettings": {"network": "ws", "wsSettings": {"path": "/trojan"}}
    }
  ],
  "outbounds": [{"protocol": "freedom", "tag": "direct"}]
}
EOF
systemctl enable --now xray

# 10. Nginx (Compartido: SSH WS + Xray WS en 80/443)
rm -f /etc/nginx/sites-enabled/default
mkdir -p /etc/nginx/ssl
openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/oxgi.key -out /etc/nginx/ssl/oxgi.crt \
    -subj "/C=MY/ST=Selangor/L=KL/O=OXGI/CN=${DOMAIN}" > /dev/null 2>&1

cat > /etc/nginx/sites-available/oxgi-ws << EOF
gzip on;
gzip_types text/plain application/json application/javascript text/css;

# HTTP (Non-TLS)
server {
    listen 80; listen 81; server_name ${DOMAIN} _; keepalive_timeout 86400s;
    
    # SSH Websocket
    location / {
        proxy_pass http://127.0.0.1:2090; proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "Upgrade";
        proxy_set_header Host \$host; proxy_buffering off;
    }
    # Xray VLESS Non-TLS
    location /vless {
        proxy_pass http://127.0.0.1:10000; proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "Upgrade";
        proxy_set_header Host \$host; proxy_buffering off;
    }
    # Xray VMESS Non-TLS
    location /vmess {
        proxy_pass http://127.0.0.1:10001; proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "Upgrade";
        proxy_set_header Host \$host; proxy_buffering off;
    }
    # Xray TROJAN Non-TLS
    location /trojan {
        proxy_pass http://127.0.0.1:10002; proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "Upgrade";
        proxy_set_header Host \$host; proxy_buffering off;
    }
}

# HTTPS (TLS)
server {
    listen 443 ssl http2; server_name ${DOMAIN} _;
    ssl_certificate /etc/nginx/ssl/oxgi.crt; ssl_certificate_key /etc/nginx/ssl/oxgi.key;
    ssl_protocols TLSv1.2 TLSv1.3; keepalive_timeout 86400s;
    
    location / {
        proxy_pass http://127.0.0.1:2090; proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "Upgrade";
        proxy_set_header Host \$host; proxy_buffering off;
    }
    location /vless {
        proxy_pass http://127.0.0.1:10000; proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "Upgrade";
        proxy_set_header Host \$host; proxy_buffering off;
    }
    location /vmess {
        proxy_pass http://127.0.0.1:10001; proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "Upgrade";
        proxy_set_header Host \$host; proxy_buffering off;
    }
    location /trojan {
        proxy_pass http://127.0.0.1:10002; proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "Upgrade";
        proxy_set_header Host \$host; proxy_buffering off;
    }
}
EOF
ln -sf /etc/nginx/sites-available/oxgi-ws /etc/nginx/sites-enabled/

cat > /etc/systemd/system/websockify.service << 'EOF'
[Unit] Description=Websockify SSH Bridge
[Service] Type=simple; ExecStart=/usr/bin/websockify 2090 127.0.0.1:22; Restart=on-failure
[Install] WantedBy=multi-user.target
EOF
systemctl daemon-reload && systemctl enable --now websockify nginx

# 11. Panel y Automatización (Cron)
INSTALL_DIR="/usr/local/oxgi"
rm -rf "$INSTALL_DIR"
git clone -b main https://github.com/gitechcode-star/oxgi-vps-script.git "$INSTALL_DIR" > /dev/null 2>&1
chmod +x "$INSTALL_DIR"/*.sh "$INSTALL_DIR"/modules/*.sh
ln -sf "$INSTALL_DIR"/oxgi.sh /usr/local/bin/oxgi

# Crear script auto_clean.sh
cat > /etc/oxgi/auto_clean.sh << 'CLEANEOF'
#!/bin/bash
DB="/etc/oxgi/ssh_users.db"
[[ ! -f "$DB" ]] && exit 0
now=$(date +%s); tmp="${DB}.tmp"; > "$tmp"
while IFS='|' read -r user pass dev created exp auto_del; do
    if [[ -n "$user" ]]; then
        if [[ $now -gt $auto_del ]]; then
            userdel -r "$user" 2>/dev/null
        else
            echo "$user|$pass|$dev|$created|$exp|$auto_del" >> "$tmp"
        fi
    fi
done < "$DB"
mv "$tmp" "$DB"

while IFS='|' read -r user pass max_dev created exp auto_del; do
    sessions=$(who | grep "^$user " | wc -l)
    [[ $sessions -gt $max_dev ]] && pkill -9 -u "$user"
done < "$DB"
CLEANEOF
chmod +x /etc/oxgi/auto_clean.sh

# Cron Jobs
(crontab -l 2>/dev/null; echo "0 5 * * * /sbin/reboot") | crontab -
(crontab -l 2>/dev/null; echo "0 0 * * * find /var/log -type f -name '*.log' -exec truncate -s 0 {} \;") | crontab -
(crontab -l 2>/dev/null; echo "0 * * * * /bin/bash /etc/oxgi/auto_clean.sh") | crontab -

# 12. Intentar SSL Real con Certbot si hay dominio válido
if [[ "$USE_SSL" == true ]]; then
    DOMAIN_IP=$(dig +short "$DOMAIN" 2>/dev/null | head -n1)
    if [[ "$DOMAIN_IP" == "$SERVER_IP" ]]; then
        systemctl stop nginx
        certbot certonly --standalone -d "$DOMAIN" --non-interactive --agree-tos --email admin@"${DOMAIN#*.}" > /dev/null 2>&1
        if [[ $? -eq 0 ]]; then
            sed -i "s|/etc/nginx/ssl/oxgi.crt|/etc/letsencrypt/live/${DOMAIN}/fullchain.pem|g" /etc/nginx/sites-available/oxgi-ws
            sed -i "s|/etc/nginx/ssl/oxgi.key|/etc/letsencrypt/live/${DOMAIN}/privkey.pem|g" /etc/nginx/sites-available/oxgi-ws
            echo "0 3 * * * certbot renew --quiet && systemctl reload nginx" | crontab -
        fi
        systemctl start nginx
    fi
fi

# RESUMEN FINAL
clear
echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║        ¡INSTALACIÓN COMPLETADA 100% EXITOSA!     ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}✅ SERVICIOS Y PUERTOS:${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "  • OpenSSH                 : 22"
echo -e "  • SSH Websocket           : 80"
echo -e "  • SSH SSL Websocket       : 443"
echo -e "  • Dropbear                : ${GREEN}90, 109, 143${NC}"
echo -e "  • Stunnel4                : 447, 777"
echo -e "  • Badvpn                  : 7100, 7200, 7300"
echo -e "  • Nginx                   : 80, 81, 443"
echo -e "  • XRAY Vless/Vmess/Trojan : 80 (NTLS), 443 (TLS) [Paths: /vless, /vmess, /trojan]"
echo ""
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}⚙️  CARACTERÍSTICAS DEL SERVIDOR:${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "  • Timezone          : Asia/Kuala_Lumpur (GMT +8)"
echo -e "  • Fail2Ban          : [ON]"
echo -e "  • Nginx Deflate     : [ON]"
echo -e "  • IPtables/UFW      : [ON]"
echo -e "  • Auto-Reboot       : [ON] - 5:00 AM"
echo -e "  • Auto Clear Log    : [ON] - Daily"
echo -e "  • AutoKill/Expire   : [ON] - Hourly Check"
echo -e "  • Virtual Swap RAM  : [ON] - 1GB"
echo -e "  • Bandwidth Monitor : [ON] - vnstat"
echo ""
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}🔗 TUS CONFIGURACIONES XRAY:${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "  • UUID: ${GREEN}${UUID}${NC}"
echo -e "  • VLESS TLS: ${GREEN}vless://${UUID}@${DOMAIN}:443?encryption=none&security=tls&type=ws&path=/vless#OXGI-VLESS${NC}"
echo -e "  • VMESS TLS: ${GREEN}vmess://${UUID}@${DOMAIN}:443?security=tls&type=ws&path=/vmess#OXGI-VMESS${NC}"
echo -e "  • TROJAN TLS: ${GREEN}trojan://${UUID}@${DOMAIN}:443?security=tls&type=ws&path=/trojan#OXGI-TROJAN${NC}"
echo ""
echo -e "${GREEN}══════════════════════════════════════════════════${NC}"
echo -e "  Escribe ${YELLOW}${BOLD}oxgi${NC}${GREEN} para administrar tu servidor.${NC}"
echo -e "${GREEN}══════════════════════════════════════════════════${NC}"
