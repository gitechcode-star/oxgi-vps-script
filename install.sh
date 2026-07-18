#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# OXGI VPS SCRIPT - Instalador con SSL REAL (Let's Encrypt)
# ═══════════════════════════════════════════════════════════════

clear

export DEBIAN_FRONTEND=noninteractive
GREEN='\033[1;32m'; RED='\033[1;31m'; YELLOW='\033[1;33m'; CYAN='\033[1;36m'; NC='\033[0m'; BOLD='\033[1m'

echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   ${GREEN}OXGI VPS - Instalador con SSL REAL${NC}${CYAN}            ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
echo ""

# ═══════════════════════════════════════════════════════════════
# SOLICITAR DOMINIO (OBLIGATORIO PARA SSL REAL)
# ═══════════════════════════════════════════════════════════════

echo -e "${YELLOW}══════════════════════════════════════════════════${NC}"
echo -e "  ${BOLD}CONFIGURACIÓN DE DOMINIO (OBLIGATORIO)${NC}"
echo -e "${YELLOW}══════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${RED}IMPORTANTE:${NC} Para instalar un certificado SSL REAL"
echo -e "  de Let's Encrypt, necesitas un dominio que apunte"
echo -e "  a la IP de este servidor mediante un registro DNS A."
echo ""
echo -e "  ${CYAN}Ejemplos de dominios válidos:${NC}"
echo -e "    • tudominio.com"
echo -e "    • vps.tudominio.com"
echo -e "    • tunombre.tk / .ml / .ga (dominios gratuitos)"
echo ""

SERVER_IP=$(curl -s https://api.ipify.org 2>/dev/null || echo "127.0.0.1")
echo -e "  ${YELLOW}IP de tu servidor: ${GREEN}${SERVER_IP}${NC}"
echo ""

read -p "  Ingresa tu dominio: " DOMAIN

if [[ -z "$DOMAIN" ]]; then
    echo ""
    echo -e "${RED}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  ERROR: Se requiere un dominio para SSL REAL     ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}INSTRUCCIONES:${NC}"
    echo "  1. Compra o registra un dominio (ej: Namecheap, Freenom)"
    echo "  2. Crea un registro DNS tipo A apuntando a: ${SERVER_IP}"
    echo "  3. Espera 5-10 minutos a que se propague el DNS"
    echo "  4. Vuelve a ejecutar este instalador"
    echo ""
    echo -e "${CYAN}Ejemplo de configuración DNS:${NC}"
    echo "    Tipo: A"
    echo "    Nombre: vps (o @ para el dominio principal)"
    echo "    Valor: ${SERVER_IP}"
    echo ""
    exit 1
fi

# ══════════════════════════════════════════════════════════════
# VERIFICAR QUE EL DOMINIO APUNTE A LA IP DEL SERVIDOR
# ═══════════════════════════════════════════════════════════════

echo ""
echo -e "${YELLOW}[*] Verificando configuración DNS...${NC}"
sleep 2

DOMAIN_IP=$(dig +short "$DOMAIN" 2>/dev/null | head -n1)

if [[ -z "$DOMAIN_IP" ]]; then
    echo -e "${RED}[ERROR] No se pudo resolver el dominio: ${DOMAIN}${NC}"
    echo -e "${YELLOW}Verifica que el dominio esté registrado correctamente.${NC}"
    exit 1
fi

echo -e "  • IP del dominio: ${CYAN}${DOMAIN_IP}${NC}"
echo -e "  • IP del servidor: ${CYAN}${SERVER_IP}${NC}"
echo ""

if [[ "$DOMAIN_IP" != "$SERVER_IP" ]]; then
    echo -e "${RED}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  ERROR: El dominio NO apunta a este servidor     ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}El dominio ${CYAN}${DOMAIN}${NC} apunta a ${RED}${DOMAIN_IP}${NC}"
    echo -e "pero este servidor tiene la IP ${GREEN}${SERVER_IP}${NC}"
    echo ""
    echo -e "${YELLOW}SOLUCIÓN:${NC}"
    echo "  1. Ve al panel de control de tu dominio"
    echo "  2. Crea o edita el registro DNS tipo A"
    echo "  3. Apunta el dominio a: ${SERVER_IP}"
    echo "  4. Espera 5-10 minutos"
    echo "  5. Vuelve a ejecutar este instalador"
    echo ""
    exit 1
fi

echo -e "${GREEN}[OK] El dominio apunta correctamente a este servidor.${NC}"
echo ""

# Guardar dominio
mkdir -p /etc/oxgi
echo "$DOMAIN" > /etc/oxgi/domain.conf

read -p "  ¿Continuar con la instalación? (s/n): " CONFIRM
[[ "$CONFIRM" != "s" && "$CONFIRM" != "S" ]] && { echo "Instalación cancelada."; exit 0; }

# Limpiar pantalla
clear

echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║      ${GREEN}INICIANDO INSTALACIÓN AUTOMÁTICA...${NC}${CYAN}       ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
echo ""

# ══════════════════════════════════════════════════════════════
# PASO 1: Actualización y Dependencias
# ═══════════════════════════════════════════════════════════════

echo -e "${YELLOW}[1/9] Actualizando sistema e instalando dependencias...${NC}"
apt update -y > /dev/null 2>&1 && apt upgrade -y > /dev/null 2>&1
apt install -y curl wget sudo cron ufw nginx python3 jq bc stunnel4 \
    build-essential cmake openssl libssl-dev websockify dropbear \
    fail2ban vnstat unzip git dnsutils certbot python3-certbot-nginx \
    apache2-utils > /dev/null 2>&1

# ═══════════════════════════════════════════════════════════════
# PASO 2: Swap RAM Virtual (1GB)
# ═══════════════════════════════════════════════════════════════

echo -e "${YELLOW}[2/9] Creando Swap RAM Virtual (1GB)...${NC}"
fallocate -l 1G /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=1024 > /dev/null 2>&1
chmod 600 /swapfile
mkswap /swapfile > /dev/null 2>&1
swapon /swapfile > /dev/null 2>&1
echo '/swapfile none swap sw 0 0' >> /etc/fstab

# ═══════════════════════════════════════════════════════════════
# PASO 3: Optimización de Red (BBR + TCP Tuning)
# ═══════════════════════════════════════════════════════════════

echo -e "${YELLOW}[3/9] Optimizando red (BBR + TCP Fast Open)...${NC}"
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
echo "net.ipv4.tcp_fastopen=3" >> /etc/sysctl.conf
echo "net.ipv4.tcp_window_scaling=1" >> /etc/sysctl.conf
echo "net.core.rmem_max=16777216" >> /etc/sysctl.conf
echo "net.core.wmem_max=16777216" >> /etc/sysctl.conf
sysctl -p > /dev/null 2>&1

# ═══════════════════════════════════════════════════════════════
# PASO 4: Firewall (IPtables/UFW)
# ═══════════════════════════════════════════════════════════════

echo -e "${YELLOW}[4/9] Configurando Firewall...${NC}"
ufw --force reset > /dev/null 2>&1
ufw allow 22/tcp; ufw allow 80/tcp; ufw allow 443/tcp; ufw allow 81/tcp
ufw allow 90/tcp; ufw allow 109/tcp; ufw allow 143/tcp
ufw allow 447/tcp; ufw allow 777/tcp; ufw allow 7100:7300/udp
echo "y" | ufw enable > /dev/null 2>&1

# ═══════════════════════════════════════════════════════════════
# PASO 5: Fail2Ban & Deflate (Nginx Gzip)
# ═══════════════════════════════════════════════════════════════

echo -e "${YELLOW}[5/9] Configurando Fail2Ban y Nginx Deflate...${NC}"
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5
[sshd]
enabled = true
port = 22,90,109,143
EOF
systemctl enable --now fail2ban > /dev/null 2>&1

# ═══════════════════════════════════════════════════════════════
# PASO 6: Stunnel4 (447, 777) y Dropbear (90, 109, 143)
# ═══════════════════════════════════════════════════════════════

echo -e "${YELLOW}[6/9] Configurando Dropbear y Stunnel...${NC}"
sed -i 's/NO_START=1/NO_START=0/' /etc/default/dropbear
sed -i 's/DROPBEAR_PORT=22/DROPBEAR_PORT=90/' /etc/default/dropbear
echo 'DROPBEAR_EXTRA_ARGS="-p 109 -p 143 -w -s -j -k"' >> /etc/default/dropbear
systemctl enable --now dropbear > /dev/null 2>&1

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
systemctl enable --now stunnel4 > /dev/null 2>&1

# ═══════════════════════════════════════════════════════════════
# PASO 7: BadVPN (7100, 7200, 7300)
# ═══════════════════════════════════════════════════════════════

echo -e "${YELLOW}[7/9] Compilando BadVPN...${NC}"
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
systemctl enable --now badvpn-${PORT} > /dev/null 2>&1
done

# ═══════════════════════════════════════════════════════════════
# PASO 8: Xray Core (Multi-Protocolo: VLESS, VMESS, TROJAN en WS)
# ═══════════════════════════════════════════════════════════════

echo -e "${YELLOW}[8/9] Instalando y configurando Xray Core...${NC}"
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
systemctl enable --now xray > /dev/null 2>&1

# ═══════════════════════════════════════════════════════════════
# PASO 9: INSTALAR CERTIFICADO SSL REAL CON LET'S ENCRYPT
# ═══════════════════════════════════════════════════════════════

echo -e "${YELLOW}[9/9] Instalando certificado SSL REAL de Let's Encrypt...${NC}"

# Detener Nginx temporalmente para que Certbot use el puerto 80
systemctl stop nginx

# Solicitar certificado SSL real
certbot certonly --standalone -d "$DOMAIN" --non-interactive --agree-tos --email admin@"${DOMAIN#*.}" > /dev/null 2>&1

if [[ $? -ne 0 ]]; then
    echo -e "${RED}[ERROR] No se pudo obtener el certificado SSL.${NC}"
    echo -e "${YELLOW}Posibles causas:${NC}"
    echo "  • El dominio no apunta correctamente a este servidor"
    echo "  • El puerto 80 está bloqueado por el firewall"
    echo "  • Ya existe un certificado para este dominio"
    echo ""
    echo -e "${CYAN}Intentando con método webroot...${NC}"
    
    # Crear directorio temporal para webroot
    mkdir -p /var/www/letsencrypt
    cat > /etc/nginx/sites-available/letsencrypt << EOF
server {
    listen 80;
    server_name ${DOMAIN};
    location /.well-known/acme-challenge/ {
        root /var/www/letsencrypt;
    }
}
EOF
    ln -sf /etc/nginx/sites-available/letsencrypt /etc/nginx/sites-enabled/
    systemctl start nginx
    
    certbot certonly --webroot -w /var/www/letsencrypt -d "$DOMAIN" --non-interactive --agree-tos --email admin@"${DOMAIN#*.}" > /dev/null 2>&1
    
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}[ERROR FATAL] No se pudo obtener el certificado SSL.${NC}"
        echo -e "${YELLOW}Verifica que:${NC}"
        echo "  1. El dominio ${DOMAIN} apunte a ${SERVER_IP}"
        echo "  2. El puerto 80 esté abierto en tu firewall"
        echo "  3. No haya otro servicio usando el puerto 80"
        echo ""
        exit 1
    fi
    
    rm -f /etc/nginx/sites-enabled/letsencrypt
fi

echo -e "${GREEN}[OK] Certificado SSL REAL instalado exitosamente.${NC}"

# ═══════════════════════════════════════════════════════════════
# CONFIGURAR NGINX CON CERTIFICADO REAL
# ═══════════════════════════════════════════════════════════════

rm -f /etc/nginx/sites-enabled/default
mkdir -p /etc/nginx/ssl

cat > /etc/nginx/sites-available/oxgi-ws << EOF
gzip on;
gzip_types text/plain application/json application/javascript text/css;

# HTTP - Redirección a HTTPS
server {
    listen 80;
    server_name ${DOMAIN};
    return 301 https://\$host\$request_uri;
}

# HTTP - Puerto 81 (para WebSocket sin TLS)
server {
    listen 81;
    server_name ${DOMAIN} _;
    keepalive_timeout 86400s;
    
    location / {
        proxy_pass http://127.0.0.1:2090;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host \$host;
        proxy_buffering off;
    }
    location /vless { proxy_pass http://127.0.0.1:10000; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "Upgrade"; proxy_buffering off; }
    location /vmess { proxy_pass http://127.0.0.1:10001; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "Upgrade"; proxy_buffering off; }
    location /trojan { proxy_pass http://127.0.0.1:10002; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "Upgrade"; proxy_buffering off; }
}

# HTTPS - Puerto 443 (con certificado REAL de Let's Encrypt)
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
        proxy_buffering off;
    }
    location /vless { proxy_pass http://127.0.0.1:10000; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "Upgrade"; proxy_buffering off; }
    location /vmess { proxy_pass http://127.0.0.1:10001; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "Upgrade"; proxy_buffering off; }
    location /trojan { proxy_pass http://127.0.0.1:10002; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "Upgrade"; proxy_buffering off; }
}
EOF

ln -sf /etc/nginx/sites-available/oxgi-ws /etc/nginx/sites-enabled/

# Websockify
cat > /etc/systemd/system/websockify.service << 'EOF'
[Unit] Description=Websockify SSH Bridge
[Service] Type=simple; ExecStart=/usr/bin/websockify 2090 127.0.0.1:22; Restart=on-failure
[Install] WantedBy=multi-user.target
EOF
systemctl daemon-reload && systemctl enable --now websockify nginx > /dev/null 2>&1

# Configurar renovación automática del certificado
echo "0 3 * * * certbot renew --quiet && systemctl reload nginx" | crontab -

# ═══════════════════════════════════════════════════════════════
# Panel y Automatización (Cron)
# ═══════════════════════════════════════════════════════════════

INSTALL_DIR="/usr/local/oxgi"
rm -rf "$INSTALL_DIR"
git clone -b main https://github.com/gitechcode-star/oxgi-vps-script.git "$INSTALL_DIR" > /dev/null 2>&1
chmod +x "$INSTALL_DIR"/*.sh "$INSTALL_DIR"/modules/*.sh
ln -sf "$INSTALL_DIR"/oxgi.sh /usr/local/bin/oxgi

cat > /etc/oxgi/auto_clean.sh << 'CLEANEOF'
#!/bin/bash
DB="/etc/oxgi/ssh_users.db"
[[ ! -f "$DB" ]] && exit 0
now=$(date +%s); tmp="${DB}.tmp"; > "$tmp"
while IFS='|' read -r user pass dev created exp auto_del; do
    if [[ -n "$user" ]]; then
        if [[ $now -gt $auto_del ]]; then userdel -r "$user" 2>/dev/null
        else echo "$user|$pass|$dev|$created|$exp|$auto_del" >> "$tmp"; fi
    fi
done < "$DB"
mv "$tmp" "$DB"
while IFS='|' read -r user pass max_dev created exp auto_del; do
    sessions=$(who | grep "^$user " | wc -l)
    [[ $sessions -gt $max_dev ]] && pkill -9 -u "$user"
done < "$DB"
CLEANEOF
chmod +x /etc/oxgi/auto_clean.sh

(crontab -l 2>/dev/null; echo "0 5 * * * /sbin/reboot") | crontab -
(crontab -l 2>/dev/null; echo "0 0 * * * find /var/log -type f -name '*.log' -exec truncate -s 0 {} \;") | crontab -
(crontab -l 2>/dev/null; echo "0 * * * * /bin/bash /etc/oxgi/auto_clean.sh") | crontab -

# ═══════════════════════════════════════════════════════════════
# RESUMEN FINAL
# ═══════════════════════════════════════════════════════════════

clear

echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   ¡INSTALACIÓN COMPLETADA CON SSL REAL!          ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}✅ SERVICIOS Y PUERTOS:${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "  • OpenSSH                 : 22"
echo -e "  • SSH Websocket (HTTP)    : 81"
echo -e "  • SSH SSL Websocket (TLS) : 443 ${GREEN}[SSL REAL]${NC}"
echo -e "  • Dropbear                : ${GREEN}90, 109, 143${NC}"
echo -e "  • Stunnel4                : 447, 777"
echo -e "  • Badvpn                  : 7100, 7200, 7300"
echo -e "  • XRAY Vless/Vmess/Trojan : 81 (NTLS), 443 (TLS)"
echo ""
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}🔒 CERTIFICADO SSL:${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "  • Dominio: ${GREEN}${DOMAIN}${NC}"
echo -e "  • Tipo: ${GREEN}Let's Encrypt (REAL)${NC}"
echo -e "  • Renovación: ${GREEN}Automática (cada 3 AM)${NC}"
echo -e "  • Validez: ${GREEN}90 días (auto-renovable)${NC}"
echo ""
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "${YELLOW} CONFIGURACIONES XRAY:${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "  • UUID: ${GREEN}${UUID}${NC}"
echo -e "  • VLESS TLS: ${GREEN}vless://${UUID}@${DOMAIN}:443?encryption=none&security=tls&type=ws&path=/vless#OXGI-VLESS${NC}"
echo -e "  • VMESS TLS: ${GREEN}vmess://${UUID}@${DOMAIN}:443?security=tls&type=ws&path=/vmess#OXGI-VMESS${NC}"
echo -e "  • TROJAN TLS: ${GREEN}trojan://${UUID}@${DOMAIN}:443?security=tls&type=ws&path=/trojan#OXGI-TROJAN${NC}"
echo ""
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}📱 CONFIGURACIÓN HTTP CUSTOM / INJECTOR:${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "  • Host: ${GREEN}${DOMAIN}${NC}"
echo -e "  • Puerto HTTPS: ${GREEN}443${NC}"
echo -e "  • Puerto HTTP: ${GREEN}81${NC}"
echo -e "  • Path: ${GREEN}/${NC}"
echo ""
echo -e "${GREEN}══════════════════════════════════════════════════${NC}"
echo -e "  Escribe ${YELLOW}${BOLD}oxgi${NC}${GREEN} para administrar tu servidor.${NC}"
echo -e "${GREEN}══════════════════════════════════════════════════${NC}"
