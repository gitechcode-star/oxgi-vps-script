#!/bin/bash
if [[ $EUID -ne 0 ]]; then echo "Ejecuta como root"; exit 1; fi
export DEBIAN_FRONTEND=noninteractive

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

clear
echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║      ${GREEN}OXGI VPS INSTALLER${NC}${CYAN}                  ${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"

read -p "Dominio: " DOMAIN
[[ -z "$DOMAIN" ]] && echo "Dominio requerido" && exit 1

mkdir -p /etc/oxgi
echo "$DOMAIN" > /etc/oxgi/domain.conf

echo -e "${YELLOW}[1/10] Actualizando...${NC}"
apt update -y && apt upgrade -y

echo -e "${YELLOW}[2/10] Instalando paquetes...${NC}"
apt install -y nginx python3 python3-pip curl wget unzip jq bc \
    openssl net-tools screen cmake g++ make cron fail2ban vnstat \
    certbot python3-certbot-nginx git

# Dropbear 2019.78 específico
echo -e "${YELLOW}[3/10] Instalando Dropbear 2019.78...${NC}"
cd /root
wget https://matt.ucc.asn.au/dropbear/releases/dropbear-2019.78.tar.bz2
tar xjf dropbear-2019.78.tar.bz2
cd dropbear-2019.78
./configure
make && make install
ln -s /usr/local/sbin/dropbear /usr/sbin/dropbear
ln -s /usr/local/bin/dbclient /usr/bin/dbclient

mkdir -p /etc/dropbear
/usr/local/sbin/dropbearkey -t rsa -f /etc/dropbear/dropbear_rsa_host_key
/usr/local/sbin/dropbearkey -t dss -f /etc/dropbear/dropbear_dss_host_key
/usr/local/sbin/dropbearkey -t ecdsa -f /etc/dropbear/dropbear_ecdsa_host_key

cat > /etc/systemd/system/dropbear.service << 'EOF'
[Unit]
Description=Dropbear SSH Server
After=network.target

[Service]
Type=forking
ExecStart=/usr/local/sbin/dropbear -p 109 -W 65536
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable dropbear
systemctl restart dropbear

# Segundo Dropbear en 143
/usr/local/sbin/dropbear -p 143 -W 65536

echo -e "${YELLOW}[4/10] Instalando Stunnel...${NC}"
apt install -y stunnel4
mkdir -p /etc/stunnel
openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
    -subj "/C=ID/ST=Jakarta/O=OXGI/CN=localhost" \
    -keyout /etc/stunnel/stunnel.key \
    -out /etc/stunnel/stunnel.crt 2>/dev/null
cat /etc/stunnel/stunnel.crt /etc/stunnel/stunnel.key > /etc/stunnel/stunnel.pem
chmod 600 /etc/stunnel/stunnel.pem

cat > /etc/stunnel/stunnel.conf << EOF
cert = /etc/stunnel/stunnel.pem
client = no
socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1
[dropbear]
accept = 447
connect = 127.0.0.1:109
[openssh]
accept = 777
connect = 127.0.0.1:22
EOF

cat > /etc/default/stunnel4 << 'EOF'
ENABLED=1
FILES="/etc/stunnel/*.conf"
EOF
systemctl enable stunnel4 && systemctl restart stunnel4

echo -e "${YELLOW}[5/10] Instalando BadVPN...${NC}"
mkdir -p /root/badvpn && cd /root/badvpn
if [[ ! -f "/usr/bin/badvpn-udpgw" ]]; then
    git clone https://github.com/ambrop72/badvpn.git . 2>/dev/null
    mkdir -p build && cd build
    cmake .. -DBUILD_NOTHING_BY_DEFAULT=ON -DBUILD_UDPGW=ON 2>/dev/null
    make 2>/dev/null
    cp udpgw/badvpn-udpgw /usr/bin/
fi

for PORT in 7100 7200 7300; do
    cat > /etc/systemd/system/badvpn-${PORT}.service << EOF
[Unit]
Description=BadVPN ${PORT}
[Service]
ExecStart=/usr/bin/badvpn-udpgw --listen-addr 127.0.0.1:${PORT} --max-clients 1000
Restart=on-failure
[Install]
WantedBy=multi-user.target
EOF
    systemctl enable badvpn-${PORT}
    systemctl restart badvpn-${PORT}
done

echo -e "${YELLOW}[6/10] Instalando WebSocket...${NC}"
pip3 install websockets

cat > /usr/local/bin/ws-stunnel << 'EOFWS'
#!/usr/bin/env python3
import asyncio, websockets, socket
async def handle_client(websocket, path):
    try:
        ssh = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        ssh.connect(('127.0.0.1', 22))
        ssh.setblocking(0)
        async def ws2ssh():
            async for msg in websocket: ssh.sendall(msg)
        async def ssh2ws():
            while True:
                await asyncio.sleep(0.01)
                try:
                    data = ssh.recv(4096)
                    if data: await websocket.send(data)
                    else: break
                except: break
        await asyncio.gather(ws2ssh(), ssh2ws())
    except: pass
    finally:
        try: websocket.close(); ssh.close()
        except: pass
async def main():
    async with websockets.serve(handle_client, '0.0.0.0', 2090): await asyncio.Future()
if __name__ == '__main__': asyncio.run(main())
EOFWS
chmod +x /usr/local/bin/ws-stunnel

cat > /etc/systemd/system/ws-stunnel.service << 'EOF'
[Unit]
Description=WebSocket Stunnel
After=network.target ssh.service
[Service]
Type=simple
ExecStart=/usr/bin/python3 /usr/local/bin/ws-stunnel
Restart=on-failure
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload && systemctl enable ws-stunnel && systemctl restart ws-stunnel

echo -e "${YELLOW}[7/10] Instalando Xray...${NC}"
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install 2>/dev/null
UUID=$(cat /proc/sys/kernel/random/uuid)
echo "$UUID" > /etc/oxgi/xray_uuid

cat > /etc/xray/config.json << EOFXRAY
{
  "log": {"loglevel": "warning"},
  "inbounds": [
    {"port": 10000, "protocol": "vmess", "settings": {"clients": [{"id": "${UUID}", "level": 0}]}, "streamSettings": {"network": "ws", "wsSettings": {"path": "/vmess"}}},
    {"port": 10001, "protocol": "vless", "settings": {"clients": [{"id": "${UUID}", "level": 0}], "decryption": "none"}, "streamSettings": {"network": "ws", "wsSettings": {"path": "/vless"}}},
    {"port": 10002, "protocol": "trojan", "settings": {"clients": [{"password": "${UUID}", "level": 0}]}, "streamSettings": {"network": "ws", "wsSettings": {"path": "/trojan"}}},
    {"port": 10003, "protocol": "shadowsocks", "settings": {"clients": [{"password": "${UUID}", "method": "aes-256-gcm"}]}, "streamSettings": {"network": "ws", "wsSettings": {"path": "/sodosok"}}}
  ],
  "outbounds": [{"protocol": "freedom"}]
}
EOFXRAY
systemctl enable xray && systemctl restart xray

echo -e "${YELLOW}[8/10] Configurando Nginx...${NC}"
cat > /etc/nginx/sites-available/oxgi << EOF
map \$http_upgrade \$connection_upgrade { default upgrade; '' close; }
server {
    listen 80; server_name ${DOMAIN};
    location / { proxy_pass http://127.0.0.1:2090; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection \$connection_upgrade; proxy_set_header Host \$host; proxy_set_header Sec-WebSocket-Version \$http_sec_websocket_version; proxy_set_header Sec-WebSocket-Key \$http_sec_websocket_key; proxy_buffering off; }
    location /vmess { proxy_pass http://127.0.0.1:10000; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection \$connection_upgrade; proxy_buffering off; }
    location /vless { proxy_pass http://127.0.0.1:10001; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection \$connection_upgrade; proxy_buffering off; }
    location /trojan { proxy_pass http://127.0.0.1:10002; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection \$connection_upgrade; proxy_buffering off; }
    location /sodosok { proxy_pass http://127.0.0.1:10003; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection \$connection_upgrade; proxy_buffering off; }
}
server {
    listen 443 ssl http2; server_name ${DOMAIN};
    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    location / { proxy_pass http://127.0.0.1:2090; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection \$connection_upgrade; proxy_set_header Host \$host; proxy_set_header Sec-WebSocket-Version \$http_sec_websocket_version; proxy_set_header Sec-WebSocket-Key \$http_sec_websocket_key; proxy_buffering off; }
    location /vmess { proxy_pass http://127.0.0.1:10000; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection \$connection_upgrade; proxy_buffering off; }
    location /vless { proxy_pass http://127.0.0.1:10001; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection \$connection_upgrade; proxy_buffering off; }
    location /trojan { proxy_pass http://127.0.0.1:10002; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection \$connection_upgrade; proxy_buffering off; }
    location /sodosok { proxy_pass http://127.0.0.1:10003; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection \$connection_upgrade; proxy_buffering off; }
}
server { listen 81; server_name 127.0.0.1 localhost; root /home/vps/public_html; location / { index index.html index.htm index.php; try_files \$uri \$uri/ /index.php?\$args; } location ~ \.php\$ { include /etc/nginx/fastcgi_params; fastcgi_pass 127.0.0.1:9000; fastcgi_index index.php; fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name; } }
EOF
ln -sf /etc/nginx/sites-available/oxgi /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl restart nginx

echo -e "${YELLOW}[9/10] Instalando SSL...${NC}"
systemctl stop nginx
certbot certonly --standalone -d "$DOMAIN" --non-interactive --agree-tos --email admin@${DOMAIN#*.} 2>/dev/null
systemctl start nginx

echo -e "${YELLOW}[10/10] Configurando Fail2Ban y auto-reboot...${NC}"
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
maxretry = 5
[sshd]
enabled = true
port = 22,109,143
EOF
systemctl enable fail2ban && systemctl restart fail2ban
echo "0 5 * * * /sbin/reboot" | crontab -

# Crear directorio de módulos
mkdir -p /usr/local/oxgi/modules

# Crear symlink para oxgi
ln -sf /usr/local/oxgi/modules/oxgi.sh /usr/local/bin/oxgi
chmod +x /usr/local/bin/oxgi

clear
echo -e "${GREEN}══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}   INSTALACIÓN COMPLETADA${NC}"
echo -e "${GREEN}══════════════════════════════════════════╝${NC}"
echo -e "SSH: ${GREEN}22${NC} | WS: ${GREEN}80,443${NC} | Dropbear: ${GREEN}109,143${NC}"
echo -e "Stunnel: ${GREEN}447,777${NC} | BadVPN: ${GREEN}7100-7300${NC}"
echo -e "WebSocket: ${GREEN}2090${NC} | Nginx: ${GREEN}81${NC}"
echo ""
echo -e "${YELLOW}Ejecuta:${NC} ${GREEN}oxgi${NC}"
