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

echo -e "${YELLOW}[1/10] Actualizando...${NC}"
apt update -y && apt upgrade -y

echo -e "${YELLOW}[2/10] Instalando paquetes base...${NC}"
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
ln -sf /usr/local/bin/dbclient /usr/bin/dbclient

mkdir -p /etc/dropbear
/usr/local/sbin/dropbearkey -t rsa -f /etc/dropbear/dropbear_rsa_host_key > /dev/null 2>&1
/usr/local/sbin/dropbearkey -t dss -f /etc/dropbear/dropbear_dss_host_key > /dev/null 2>&1
/usr/local/sbin/dropbearkey -t ecdsa -f /etc/dropbear/dropbear_ecdsa_host_key > /dev/null 2>&1

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
pkill -9 dropbear || true
sleep 1
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
OPTIONS="-p /etc/stunnel/stunnel.pem"
EOF

# Limpiar puertos colgados y reiniciar stunnel
pkill -9 stunnel4 || true
fuser -k 447/tcp 777/tcp 2>/dev/null || true
sleep 2
systemctl enable stunnel4
systemctl restart stunnel4

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
    systemctl enable badvpn-${PORT}
    systemctl restart badvpn-${PORT}
done

echo -e "${YELLOW}[6/10] Instalando WebSocket (API Corregida)...${NC}"
pip3 install --upgrade websockets > /dev/null 2>&1

# SCRIPT PYTHON CORREGIDO PARA WEBSOCKETS >= 10.0 (Sin argumento 'path')
cat > /usr/local/bin/ws-stunnel << 'EOFWS'
#!/usr/bin/env python3
import asyncio
import websockets
import socket
import sys

async def handle_client(websocket):
    try:
        ssh = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        ssh.connect(('127.0.0.1', 22))
        ssh.setblocking(0)
        
        async def ws2ssh():
            try:
                async for msg in websocket:
                    ssh.sendall(msg)
            except:
                pass
                
        async def ssh2ws():
            try:
                while True:
                    await asyncio.sleep(0.01)
                    try:
                        data = ssh.recv(4096)
                        if data:
                            await websocket.send(data)
                        else:
                            break
                    except BlockingIOError:
                        await asyncio.sleep(0.01)
                        continue
                    except:
                        break
            except:
                pass
                
        await asyncio.gather(ws2ssh(), ssh2ws())
    except Exception as e:
        pass
    finally:
        try:
            await websocket.close()
        except:
            pass
        try:
            ssh.close()
        except:
            pass

async def main():
    async with websockets.serve(handle_client, '0.0.0.0', 2090):
        await asyncio.Future()

if __name__ == '__main__':
    try:
        asyncio.run(main())
    except Exception as e:
        print(f"WebSocket Error: {e}", file=sys.stderr)
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
nginx -t > /dev/null 2>&1 && systemctl restart nginx

echo -e "${YELLOW}[9/10] Instalando SSL...${NC}"
systemctl stop nginx
certbot certonly --standalone -d "$DOMAIN" --non-interactive --agree-tos --email admin@${DOMAIN#*.} > /dev/null 2>&1
systemctl start nginx

echo -e "${YELLOW}[10/10] Creando módulos y comandos...${NC}"
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

# === CREACIÓN DE LOS ARCHIVOS DE MÓDULOS ===
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

cat > /usr/local/oxgi/modules/users.sh << 'EOFUSERS'
#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
DB="/etc/oxgi/ssh_users.db"
mkdir -p /etc/oxgi && touch "$DB"
crear() {
    clear; echo -e "${CYAN}CREAR USUARIO SSH${NC}\n"
    read -p "Usuario: " user
    [[ ! "$user" =~ ^[a-zA-Z0-9_]+$ ]] || [[ ${#user} -lt 3 ]] && { echo -e "${RED}Inválido${NC}"; read -p "ENTER"; return; }
    id "$user" &>/dev/null && { echo -e "${RED}Existe${NC}"; read -p "ENTER"; return; }
    read -p "Password (blank=auto): " pass
    [[ -z "$pass" ]] && pass=$(openssl rand -base64 10 | tr -dc 'a-zA-Z0-9' | head -c8)
    echo -e "\n[1] Minutos [2] Horas [3] Días [4] Meses [5] Años"
    read -p "Unidad: " u
    case $u in 1) m=60;; 2) m=3600;; 3) m=86400;; 4) m=2592000;; 5) m=31536000;; *) echo "Inválido"; return;; esac
    read -p "Cantidad: " c
    [[ ! "$c" =~ ^[0-9]+$ ]] && { echo "Inválido"; return; }
    read -p "Max dispositivos: " dev
    [[ ! "$dev" =~ ^[0-9]+$ ]] && { echo "Inválido"; return; }
    exp=$(date -d "+$((c*m)) seconds" +"%Y-%m-%d %H:%M:%S")
    expd=$(echo "$exp" | cut -d' ' -f1)
    useradd -e "$expd" -s /bin/false -M "$user"
    echo "$user:$pass" | chpasswd
    echo "${user}:$(date +%s):${exp}:${dev}" >> "$DB"
    echo -e "\n${GREEN}Creado:${NC} $user | Pass: $pass | Exp: $exp | Dev: $dev"
    read -p "ENTER"
}
eliminar() {
    clear; echo -e "${CYAN}ELIMINAR USUARIO${NC}\n"
    read -p "Usuario: " user
    id "$user" &>/dev/null || { echo -e "${RED}No existe${NC}"; read -p "ENTER"; return; }
    userdel -r "$user" 2>/dev/null
    sed -i "/^${user}:/d" "$DB"
    echo -e "${GREEN}Eliminado${NC}"; read -p "ENTER"
}
lista() {
    clear; echo -e "${CYAN}USUARIOS${NC}\n"
    [[ ! -s "$DB" ]] && { echo "Sin usuarios"; read -p "ENTER"; return; }
    printf "%-15s %-25s %-5s\n" "USER" "EXPIRA" "DEV"
    while IFS=':' read -r u t e d; do printf "%-15s %-25s %-5s\n" "$u" "$e" "$d"; done < "$DB"
    read -p "ENTER"
}
online() {
    clear; echo -e "${CYAN}ONLINE${NC}\n"
    who | awk '{print $1}' | sort | uniq -c
    read -p "ENTER"
}
while true; do
    clear; echo -e "${CYAN}USER MANAGER${NC}\n"
    echo "[1] Crear [2] Eliminar [3] Lista [4] Online [0] Salir"
    read -p "Opción: " o
    case $o in 1) crear;; 2) eliminar;; 3) lista;; 4) online;; 0) exit 0;; esac
done
EOFUSERS
chmod +x /usr/local/oxgi/modules/users.sh

cat > /usr/local/oxgi/modules/v2ray.sh << 'EOFV2RAY'
#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
DOMAIN=$(cat /etc/oxgi/domain.conf)
UUID=$(cat /etc/oxgi/xray_uuid)
DB="/etc/oxgi/v2ray.db"
mkdir -p /etc/oxgi && touch "$DB"
add_vmess() {
    clear; echo -e "${CYAN}VMESS${NC}\n"
    read -p "Nombre: " name; [[ -z "$name" ]] && return
    read -p "Días: " days; [[ ! "$days" =~ ^[0-9]+$ ]] && return
    exp=$(date -d "+$days days" +"%Y-%m-%d")
    echo "${name}:${UUID}:vmess:${exp}" >> "$DB"
    echo -e "\n${GREEN}$name${NC} - Exp: $exp"
    echo "vmess://$(echo '{"v":"2","ps":"'$name'","add":"'$DOMAIN'","port":"443","id":"'$UUID'","net":"ws","path":"/vmess","tls":"tls"}' | base64 -w0)"
    read -p "ENTER"
}
add_vless() {
    clear; echo -e "${CYAN}VLESS${NC}\n"
    read -p "Nombre: " name; [[ -z "$name" ]] && return
    read -p "Días: " days; [[ ! "$days" =~ ^[0-9]+$ ]] && return
    exp=$(date -d "+$days days" +"%Y-%m-%d")
    echo "${name}:${UUID}:vless:${exp}" >> "$DB"
    echo -e "\n${GREEN}$name${NC} - Exp: $exp"
    echo "vless://${UUID}@${DOMAIN}:443?encryption=none&security=tls&type=ws&path=/vless#${name}"
    read -p "ENTER"
}
add_trojan() {
    clear; echo -e "${CYAN}TROJAN${NC}\n"
    read -p "Nombre: " name; [[ -z "$name" ]] && return
    read -p "Días: " days; [[ ! "$days" =~ ^[0-9]+$ ]] && return
    exp=$(date -d "+$days days" +"%Y-%m-%d")
    echo "${name}:${UUID}:trojan:${exp}" >> "$DB"
    echo -e "\n${GREEN}$name${NC} - Exp: $exp"
    echo "trojan://${UUID}@${DOMAIN}:443?security=tls&type=ws&path=/trojan#${name}"
    read -p "ENTER"
}
lista() {
    clear; echo -e "${CYAN}V2RAY USERS${NC}\n"
    [[ ! -s "$DB" ]] && { echo "Sin usuarios"; read -p "ENTER"; return; }
    printf "%-15s %-10s %-20s\n" "USER" "TYPE" "EXPIRA"
    while IFS=':' read -r n u t e; do printf "%-15s %-10s %-20s\n" "$n" "$t" "$e"; done < "$DB"
    read -p "ENTER"
}
while true; do
    clear; echo -e "${CYAN}V2RAY MANAGER${NC}\n"
    echo "[1] VMESS [2] VLESS [3] TROJAN [4] Lista [0] Salir"
    read -p "Opción: " o
    case $o in 1) add_vmess;; 2) add_vless;; 3) add_trojan;; 4) lista;; 0) exit 0;; esac
done
EOFV2RAY
chmod +x /usr/local/oxgi/modules/v2ray.sh

cat > /usr/local/oxgi/modules/nginx.sh << 'EOFNGINX'
#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
while true; do
    clear; echo -e "${GREEN}NGINX MANAGER${NC}\n"
    echo "[1] Restart [2] Stop [3] Start [4] Status [5] Test [0] Exit"
    read -p "Option: " o
    case $o in
        1) systemctl restart nginx; echo "Done"; read -p "ENTER";;
        2) systemctl stop nginx; echo "Done"; read -p "ENTER";;
        3) systemctl start nginx; echo "Done"; read -p "ENTER";;
        4) systemctl status nginx --no-pager; read -p "ENTER";;
        5) nginx -t; read -p "ENTER";;
        0) exit 0;;
    esac
done
EOFNGINX
chmod +x /usr/local/oxgi/modules/nginx.sh

cat > /usr/local/oxgi/modules/websocket.sh << 'EOFWSMOD'
#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
while true; do
    clear; echo -e "${GREEN}WEBSOCKET MANAGER${NC}\n"
    echo "[1] Restart [2] Stop [3] Start [4] Status [5] Logs [0] Exit"
    read -p "Option: " o
    case $o in
        1) systemctl restart ws-stunnel; echo "Done"; read -p "ENTER";;
        2) systemctl stop ws-stunnel; echo "Done"; read -p "ENTER";;
        3) systemctl start ws-stunnel; echo "Done"; read -p "ENTER";;
        4) systemctl status ws-stunnel --no-pager; read -p "ENTER";;
        5) journalctl -u ws-stunnel -n 30 --no-pager; read -p "ENTER";;
        0) exit 0;;
    esac
done
EOFWSMOD
chmod +x /usr/local/oxgi/modules/websocket.sh

clear
echo -e "${GREEN}══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}   INSTALACIÓN COMPLETADA${NC}"
echo -e "${GREEN}══════════════════════════════════════════╝${NC}"
echo -e "SSH: ${GREEN}22${NC} | WS: ${GREEN}80,443${NC} | Dropbear: ${GREEN}109,143${NC}"
echo -e "Stunnel: ${GREEN}447,777${NC} | BadVPN: ${GREEN}7100-7300${NC}"
echo -e "WebSocket: ${GREEN}2090${NC} | Nginx: ${GREEN}81${NC}"
echo ""
echo -e "${YELLOW}Ejecuta:${NC} ${GREEN}oxgi${NC}"
