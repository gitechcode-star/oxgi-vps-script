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

mkdir -p /etc/oxgi /usr/local/oxgi/modules
echo "$DOMAIN" > /etc/oxgi/domain.conf

echo -e "${YELLOW}[1/10] Actualizando sistema...${NC}"
apt update -y && apt upgrade -y

echo -e "${YELLOW}[2/10] Instalando paquetes base...${NC}"
apt install -y nginx python3 curl wget unzip jq bc openssl net-tools \
    screen cmake g++ make cron fail2ban vnstat certbot python3-certbot-nginx git

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
pkill -9 stunnel4 || true; sleep 2
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

echo -e "${YELLOW}[6/10] Instalando WebSocket (Lógica EXACTA de Blueblue)...${NC}"
# Este es el script ws-stunnel de Blueblue, adaptado a Python 3 para compatibilidad moderna
# Hace un "fake handshake" y luego reenvío TCP ciego, exactamente como lo hace Blueblue.
cat > /usr/local/bin/ws-stunnel << 'EOFWS'
#!/usr/bin/env python3
import socket, threading, select, sys, time

LISTENING_ADDR = '0.0.0.0'
LISTENING_PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 2090
PASS = ''
BUFLEN = 4096 * 4
TIMEOUT = 60
DEFAULT_HOST = '127.0.0.1:22'
RESPONSE = b'HTTP/1.1 101 Switching Protocols\r\n\r\nContent-Length: 104857600000\r\n\r\n'

class Server(threading.Thread):
    def __init__(self, host, port):
        threading.Thread.__init__(self)
        self.running = False
        self.host = host
        self.port = port
        self.threads = []
        self.threadsLock = threading.Lock()

    def run(self):
        self.soc = socket.socket(socket.AF_INET)
        self.soc.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.soc.settimeout(2)
        self.soc.bind((self.host, self.port))
        self.soc.listen(0)
        self.running = True
        try:
            while self.running:
                try:
                    c, addr = self.soc.accept()
                    c.setblocking(True)
                except socket.timeout:
                    continue
                conn = ConnectionHandler(c, self, addr)
                conn.start()
                with self.threadsLock:
                    if self.running: self.threads.append(conn)
        finally:
            self.running = False
            self.soc.close()

    def close(self):
        self.running = False
        with self.threadsLock:
            for c in list(self.threads): c.close()

class ConnectionHandler(threading.Thread):
    def __init__(self, socClient, server, addr):
        threading.Thread.__init__(self)
        self.clientClosed = False
        self.targetClosed = True
        self.client = socClient
        self.server = server
        self.log = f'Connection: {addr}'

    def close(self):
        try:
            if not self.clientClosed:
                self.client.shutdown(socket.SHUT_RDWR)
                self.client.close()
        except: pass
        finally: self.clientClosed = True
        try:
            if not self.targetClosed:
                self.target.shutdown(socket.SHUT_RDWR)
                self.target.close()
        except: pass
        finally: self.targetClosed = True

    def run(self):
        try:
            client_buffer = self.client.recv(BUFLEN)
            hostPort = self.findHeader(client_buffer, b'X-Real-Host')
            if hostPort == b'': hostPort = DEFAULT_HOST.encode()
            
            passwd = self.findHeader(client_buffer, b'X-Pass')
            if len(PASS) != 0 and passwd.decode() != PASS:
                self.client.send(b'HTTP/1.1 400 WrongPass!\r\n\r\n')
            else:
                self.method_CONNECT(hostPort.decode())
        except Exception as e:
            pass
        finally:
            self.close()
            with self.server.threadsLock:
                if self in self.server.threads: self.server.threads.remove(self)

    def findHeader(self, head, header):
        aux = head.find(header + b': ')
        if aux == -1: return b''
        aux = head.find(b':', aux)
        head = head[aux+2:]
        aux = head.find(b'\r\n')
        return head[:aux] if aux != -1 else b''

    def connect_target(self, host):
        i = host.find(':')
        if i != -1:
            port = int(host[i+1:])
            host = host[:i]
        else:
            port = 22
        self.target = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.targetClosed = False
        self.target.connect((host, port))

    def method_CONNECT(self, path):
        self.connect_target(path)
        self.client.sendall(RESPONSE)
        self.doCONNECT()

    def doCONNECT(self):
        socs = [self.client, self.target]
        count = 0
        while True:
            count += 1
            (recv, _, err) = select.select(socs, [], socs, 3)
            if err or count == TIMEOUT: break
            if recv:
                for in_ in recv:
                    try:
                        data = in_.recv(BUFLEN)
                        if not data: break
                        if in_ is self.target: self.client.send(data)
                        else: self.target.sendall(data)
                        count = 0
                    except: break

def main():
    print(f"WebSocket listening on {LISTENING_ADDR}:{LISTENING_PORT}")
    server = Server(LISTENING_ADDR, LISTENING_PORT)
    server.start()
    try:
        while True: time.sleep(2)
    except KeyboardInterrupt:
        server.close()

if __name__ == '__main__':
    main()
EOFWS
chmod +x /usr/local/bin/ws-stunnel

cat > /etc/systemd/system/ws-stunnel.service << 'EOF'
[Unit]
Description=WebSocket Stunnel (Blueblue Logic)
After=network.target ssh.service
[Service]
Type=simple
User=root
ExecStart=/usr/bin/python3 /usr/local/bin/ws-stunnel 2090
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

echo -e "${YELLOW}[10/10] Creando módulos OXGI...${NC}"
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

# (Asume que users.sh, v2ray.sh, nginx.sh, websocket.sh ya están creados como en la respuesta anterior)

clear
echo -e "${GREEN}══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}   INSTALACIÓN COMPLETADA${NC}"
echo -e "${GREEN}══════════════════════════════════════════╝${NC}"
echo -e "SSH: ${GREEN}22${NC} | WS: ${GREEN}80,443${NC} | Dropbear: ${GREEN}109,143${NC}"
echo -e "Stunnel: ${GREEN}447,777${NC} | BadVPN: ${GREEN}7100-7300${NC}"
echo -e "WebSocket: ${GREEN}2090${NC} | Nginx: ${GREEN}81${NC}"
echo ""
echo -e "${YELLOW}Ejecuta:${NC} ${GREEN}oxgi${NC}"
