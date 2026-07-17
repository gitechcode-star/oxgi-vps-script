#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# OXGI VPS SCRIPT - Instalador Profesional (Nivel Blueblue)
# ═══════════════════════════════════════════════════════════════

export DEBIAN_FRONTEND=noninteractive
GREEN='\033[1;32m'; RED='\033[1;31m'; YELLOW='\033[1;33m'; CYAN='\033[1;36m'; NC='\033[0m'

echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║      ${GREEN}OXGI VPS - INSTALACIÓN PROFESIONAL${NC}${CYAN}      ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"

# 1. Actualización y Dependencias
echo -e "${YELLOW}[1/6] Actualizando sistema e instalando dependencias...${NC}"
apt update -y && apt upgrade -y
apt install -y curl wget sudo cron ufw nginx python3 jq bc \
    build-essential cmake openssl libssl-dev websockify dropbear \
    fail2ban vnstat unzip git

# 2. Optimización de Red Extrema (Velocidad "Super Rápida")
echo -e "${YELLOW}[2/6] Optimizando red (BBR + TCP Tuning)...${NC}"
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
echo "net.ipv4.tcp_fastopen=3" >> /etc/sysctl.conf
echo "net.ipv4.tcp_window_scaling=1" >> /etc/sysctl.conf
echo "net.core.rmem_max=16777216" >> /etc/sysctl.conf
echo "net.core.wmem_max=16777216" >> /etc/sysctl.conf
echo "net.ipv4.tcp_rmem=4096 87380 16777216" >> /etc/sysctl.conf
echo "net.ipv4.tcp_wmem=4096 65536 16777216" >> /etc/sysctl.conf
sysctl -p > /dev/null 2>&1

# 3. Firewall
echo -e "${YELLOW}[3/6] Configurando Firewall (UFW)...${NC}"
ufw --force reset
ufw allow 22/tcp; ufw allow 80/tcp; ufw allow 443/tcp
ufw allow 444/tcp; ufw allow 109/tcp; ufw allow 143/tcp
ufw allow 7100:7300/udp; ufw allow 81/tcp
echo "y" | ufw enable > /dev/null 2>&1

# 4. Configuración Nginx + Websockify (SSH WS 80/443)
echo -e "${YELLOW}[4/6] Configurando WebSocket SSH (Puertos 80/443)...${NC}"
rm -f /etc/nginx/sites-enabled/default
mkdir -p /etc/nginx/ssl
openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/oxgi.key -out /etc/nginx/ssl/oxgi.crt \
    -subj "/C=MY/ST=State/L=City/O=OXGI/CN=oxgi.local" > /dev/null 2>&1

cat > /etc/nginx/sites-available/oxgi-ws << 'EOF'
# HTTP (Non-TLS)
server {
    listen 80;
    server_name _;
    location / {
        proxy_pass http://127.0.0.1:2090;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
# HTTPS (TLS)
server {
    listen 443 ssl http2;
    server_name _;
    ssl_certificate /etc/nginx/ssl/oxgi.crt;
    ssl_certificate_key /etc/nginx/ssl/oxgi.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    location / {
        proxy_pass http://127.0.0.1:2090;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
EOF
ln -sf /etc/nginx/sites-available/oxgi-ws /etc/nginx/sites-enabled/

cat > /etc/systemd/system/websockify.service << 'EOF'
[Unit]
Description=Websockify SSH Bridge
After=network.target
[Service]
Type=simple
ExecStart=/usr/bin/websockify 2090 127.0.0.1:22
Restart=on-failure
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload && systemctl enable --now websockify nginx

# 5. Dropbear & BadVPN
echo -e "${YELLOW}[5/6] Configurando Dropbear y BadVPN...${NC}"
sed -i 's/NO_START=1/NO_START=0/' /etc/default/dropbear
sed -i 's/DROPBEAR_PORT=22/DROPBEAR_PORT=109/' /etc/default/dropbear
echo "DROPBEAR_EXTRA_ARGS=\"-p 143 -w -s -j -k\"" >> /etc/default/dropbear
systemctl enable --now dropbear

mkdir -p /tmp/badvpn && cd /tmp/badvpn
git clone https://github.com/ambrop72/badvpn.git . > /dev/null 2>&1
mkdir build && cd build
cmake .. -DBUILD_NOTHING_BY_DEFAULT=ON -DBUILD_UDPGW=ON > /dev/null 2>&1
make > /dev/null 2>&1
cp udpgw/badvpn-udpgw /usr/bin/
cat > /etc/systemd/system/badvpn.service << 'EOF'
[Unit]
Description=BadVPN UDPGW
After=network.target
[Service]
ExecStart=/usr/bin/badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 1000
Restart=on-failure
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload && systemctl enable --now badvpn

# 6. Descargar Script y Automatización (Cron)
echo -e "${YELLOW}[6/6] Instalando Panel OXGI y Automatización...${NC}"
INSTALL_DIR="/usr/local/oxgi"
mkdir -p $INSTALL_DIR /etc/oxgi
git clone -b main https://github.com/gitechcode-star/oxgi-vps-script.git $INSTALL_DIR > /dev/null 2>&1
chmod +x $INSTALL_DIR/*.sh $INSTALL_DIR/modules/*.sh
ln -sf $INSTALL_DIR/oxgi.sh /usr/local/bin/oxgi

# Cron Jobs (Auto Reboot 5AM, Auto Clear Log, Auto Delete Expired)
(crontab -l 2>/dev/null; echo "0 5 * * * /sbin/reboot") | crontab -
(crontab -l 2>/dev/null; echo "0 0 * * * find /var/log -type f -name '*.log' -exec truncate -s 0 {} \;") | crontab -
(crontab -l 2>/dev/null; echo "0 * * * * /usr/local/oxgi/modules/auto_clean.sh") | crontab -

clear
echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║        ¡INSTALACIÓN COMPLETADA EXITOSAMENTE!     ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
echo -e "${CYAN}• SSH WS (80/443) | Dropbear (109/143) | BadVPN (7300)${NC}"
echo -e "${CYAN}• Optimización de red BBR + TCP Fast Open ACTIVADA${NC}"
echo -e "${CYAN}• Auto-Reboot (5:00 AM) y Limpieza de Logs ACTIVADA${NC}"
echo -e "${GREEN}Escribe ${YELLOW}oxgi${GREEN} para comenzar.${NC}"
