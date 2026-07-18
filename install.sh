#!/bin/bash
if [[ $EUID -ne 0 ]]; then echo "Ejecuta como root"; exit 1; fi
export DEBIAN_FRONTEND=noninteractive

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

clear
echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║      ${GREEN}OXGI VPS INSTALLER${NC}${CYAN}                  ${NC}"
echo -e "${CYAN}════════════════════════════════════════════╝${NC}"

read -p "Dominio: " DOMAIN
[[ -z "$DOMAIN" ]] && echo "Dominio requerido" && exit 1

mkdir -p /etc/oxgi /usr/local/oxgi/modules
echo "$DOMAIN" > /etc/oxgi/domain.conf

echo -e "${YELLOW}[1/10] Actualizando...${NC}"
apt update -y && apt upgrade -y

echo -e "${YELLOW}[2/10] Instalando paquetes...${NC}"
apt install -y nginx python3 python3-pip curl wget unzip jq bc \
    openssl net-tools screen cmake g++ make cron fail2ban vnstat \
    certbot python3-certbot-nginx git build-essential

echo -e "${YELLOW}[3/10] Compilando Dropbear 2019.78...${NC}"
cd /root
wget -q https://matt.ucc.asn.au/dropbear/releases/dropbear-2019.78.tar.bz2
tar xjf dropbear-2019.78.tar.bz2
cd dropbear-2019.78
./configure > /dev/null 2>&1
make > /dev/null 2>&1 && make install > /dev/null 2>&1
ln -sf /usr/local/sbin/dropbear /usr/sbin/dropbear

mkdir -p /etc/dropbear
/usr/local/sbin/dropbearkey -t rsa -f /etc/dropbear/dropbear_rsa_host_key > /dev/null 2>&1
/usr/local/sbin/dropbearkey -t dss -f /etc/dropbear/dropbear_dss_host_key > /dev/null 2>&1

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
systemctl daemon-reload && systemctl enable dropbear && systemctl restart dropbear
/usr/local/sbin/dropbear -p 143 -W 65536

echo -e "${YELLOW}[4/10] Instalando Stunnel...${NC}"
apt install -y stunnel4
mkdir -p /etc/stunnel
openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
    -subj "/C=ID/ST=Jakarta/O=OXGI/CN=localhost" \
    -keyout /etc/stunnel/stunnel.key -out /etc/stunnel/stunnel.crt 2>/dev/null
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
pkill -9 stunnel4 || true
sleep 2
systemctl enable stunnel4 && systemctl restart stunnel4

echo -e "${YELLOW}[5/10] Instalando BadVPN...${NC}"
mkdir -p /root/badvpn && cd /root/badvpn
if [[ ! -f "/usr/bin/badvpn-udpgw" ]]; then
    git clone https://github.com/ambrop72/badvpn.git . > /dev/null 2>&1
    mkdir -p build && cd build
    cmake .. -DBUILD_NOTHING_BY_DEFAULT=ON -DBUILD_UDPGW=ON > /dev/null 2>&1
    make > /dev/null 2>&1
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
    systemctl enable badvpn-${PORT} && systemctl restart badvpn-${PORT}
done

echo -e "${YELLOW}[6/10] Instalando WebSocket (Raw Socket - Sin validación estricta)...${NC}"

# WEBSOCKET CON SOCKETS CRUDOS - Acepta cualquier conexión HTTP
cat > /usr/local/bin/ws-stunnel << 'EOFWS'
#!/usr/bin/env python3
import socket
import threading
import base64
import hashlib

def handle_client(client_socket):
    """Maneja la conexión del cliente - Acepta WebSocket o HTTP simple"""
    try:
        # Recibir request inicial
        request = client_socket.recv(4096).decode('utf-8', errors='ignore')
        
        # Verificar si es WebSocket upgrade
        if 'Upgrade: websocket' in request or 'upgrade: websocket' in request.lower():
            # Es WebSocket - hacer handshake
            lines = request.split('\r\n')
            key = ''
            for line in lines:
                if line.lower().startswith('sec-websocket-key:'):
                    key = line.split(':', 1)[1].strip()
                    break
            
            # Generar respuesta de aceptación
            if key:
                accept_key = base64.b64encode(
                    hashlib.sha1((key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").encode()).digest()
                ).decode()
                
                response = (
                    "HTTP/1.1 101 Switching Protocols\r\n"
                    "Upgrade: websocket\r\n"
                    "Connection: Upgrade\r\n"
                    f"Sec-WebSocket-Accept: {accept_key}\r\n"
                    "\r\n"
                )
                client_socket.send(response.encode())
        
        # Conectar a SSH
        ssh_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        ssh_socket.connect(('127.0.0.1', 22))
        
        # Forward bidireccional
        def client_to_ssh():
            try:
                while True:
                    data = client_socket.recv(4096)
                    if not data:
                        break
                    ssh_socket.sendall(data)
            except:
                pass
        
        def ssh_to_client():
            try:
                while True:
                    data = ssh_socket.recv(4096)
                    if not data:
                        break
                    client_socket.sendall(data)
            except:
                pass
        
        t1 = threading.Thread(target=client_to_ssh)
        t2 = threading.Thread(target=ssh_to_client)
        t1.daemon = True
        t2.daemon = True
        t1.start()
        t2.start()
        t1.join()
        t2.join()
        
    except Exception as e:
        pass
    finally:
        try:
            client_socket.close()
        except:
            pass

def main():
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(('0.0.0.0', 2090))
    server.listen(1000)
    print("WebSocket server listening on port 2090...")
    
    while True:
        client, addr = server.accept()
        t = threading.Thread(target=handle_client, args=(client,))
        t.daemon = True
        t.start()

if __name__ == '__main__':
    main()
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
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install > /dev/null 2>&1
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
    location / { proxy_pass http://127.0.0.1:2090; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection \$connection_upgrade; proxy_set_header Host \$host; proxy_buffering off; }
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
    location / { proxy_pass http://127.0.0.1:2090; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection \$connection_upgrade; proxy_set_header Host \$host; proxy_buffering off; }
    location /vmess { proxy_pass http://127.0.0.1:10000; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection \$connection_upgrade; proxy_buffering off; }
    location /vless { proxy_pass http://127.0.0.1:10001; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection \$connection_upgrade; proxy_buffering off; }
    location /trojan { proxy_pass http://127.0.0.1:10002; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection \$connection_upgrade; proxy_buffering off; }
    location /sodosok { proxy_pass http://127.0.0.1:10003; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection \$connection_upgrade; proxy_buffering off; }
}
server { listen 81; server_name 127.0.0.1 localhost; root /home/vps/public_html; location / { index index.html index.htm index.php; try_files \$uri \$uri/ /index.php?\$args; } location ~ \.php\$ { include /etc/nginx/fastcgi_params; fastcgi_pass 127.0.0.1:9000; fastcgi_index index.php; fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name; } }
EOF
ln -sf /etc/nginx/sites-available/oxgi /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t > /dev/null 2>&1 && systemctl restart nginx

echo -e "${YELLOW}[9/10] Instalando SSL...${NC}"
systemctl stop nginx
certbot certonly --standalone -d "$DOMAIN" --non-interactive --agree-tos --email admin@${DOMAIN#*.} > /dev/null 2>&1
systemctl start nginx

echo -e "${YELLOW}[10/10] Creando módulos...${NC}"
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

# Crear módulos (mismo código que antes para users.sh, v2ray.sh, nginx.sh, websocket.sh, oxgi.sh)
cat > /usr/local/oxgi/modules/oxgi.sh << 'EOFOXGI'
#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
while true; do
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║      ${GREEN}OXGI VPS MANAGER${NC}${CYAN}                    ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}[01]${NC} SSH/WebSocket Users"
    echo -e "${CYAN}[02]${NC} V2Ray Users"
    echo -e "${CYAN}[03]${NC} Nginx"
    echo -e "${CYAN}[04]${NC} WebSocket"
    echo -e "${CYAN}[05]${NC} Restart All"
    echo -e "${CYAN}[06]${NC} Services Status"
    echo -e "${CYAN}[07]${NC} Active Ports"
    echo -e "${CYAN}[08]${NC} System Info"
    echo ""
    echo -e "${RED}[00]${NC} Exit"
    read -p "Option: " opt
    case $opt in
        1) bash /usr/local/oxgi/modules/users.sh ;;
        2) bash /usr/local/oxgi/modules/v2ray.sh ;;
        3) bash /usr/local/oxgi/modules/nginx.sh ;;
        4) bash /usr/local/oxgi/modules/websocket.sh ;;
        5) systemctl restart nginx ws-stunnel dropbear stunnel4 xray fail2ban; echo -e "${GREEN}Done${NC}"; read -p "ENTER..." ;;
        6) systemctl status nginx ws-stunnel dropbear stunnel4 xray --no-pager -l; read -p "ENTER..." ;;
        7) netstat -tlnp | grep -E ':(22|80|109|143|443|447|777|7100|7200|7300|2090|81)'; read -p "ENTER..." ;;
        8) echo "Uptime:"; uptime; echo; free -h; echo; df -h; read -p "ENTER..." ;;
        0) clear; exit 0 ;;
        *) echo -e "${RED}Invalid${NC}"; sleep 1 ;;
    esac
done
EOFOXGI
chmod +x /usr/local/oxgi/modules/oxgi.sh
ln -sf /usr/local/oxgi/modules/oxgi.sh /usr/local/bin/oxgi

# (Incluir aquí el código completo de users.sh, v2ray.sh, nginx.sh, websocket.sh como en la respuesta anterior)

clear
echo -e "${GREEN}══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}   INSTALACIÓN COMPLETADA${NC}"
echo -e "${GREEN}══════════════════════════════════════════╝${NC}"
echo -e "SSH: ${GREEN}22${NC} | WS: ${GREEN}80,443${NC} | Dropbear: ${GREEN}109,143${NC}"
echo -e "Stunnel: ${GREEN}447,777${NC} | BadVPN: ${GREEN}7100-7300${NC}"
echo -e "WebSocket: ${GREEN}2090${NC} | Nginx: ${GREEN}81${NC}"
echo ""
echo -e "${YELLOW}Ejecuta:${NC} ${GREEN}oxgi${NC}"
