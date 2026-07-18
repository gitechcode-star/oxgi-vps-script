#!/bin/bash
if [[ $EUID -ne 0 ]]; then echo "Ejecuta como root"; exit 1; fi
export DEBIAN_FRONTEND=noninteractive

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

clear
echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║      ${GREEN}OXGI VPS INSTALLER${NC}${CYAN}                 ║${NC}"
echo -e "${CYAN}════════════════════════════════════════════╝${NC}"

read -p "Dominio: " DOMAIN
[[ -z "$DOMAIN" ]] && echo "Dominio requerido" && exit 1
mkdir -p /etc/oxgi
echo "$DOMAIN" > /etc/oxgi/domain.conf

echo -e "${YELLOW}[1/12] Actualizando sistema...${NC}"
apt update -y && apt upgrade -y

echo -e "${YELLOW}[2/12] Instalando paquetes base...${NC}"
apt install -y nginx dropbear stunnel4 websockify python3 python3-pip \
    fail2ban vnstat unzip git curl wget jq bc openssl net-tools \
    screen cmake g++ make cron

echo -e "${YELLOW}[3/12] Configurando SSH (22)...${NC}"
systemctl enable ssh

echo -e "${YELLOW}[4/12] Configurando Dropbear (109, 143)...${NC}"
sed -i 's/NO_START=1/NO_START=0/' /etc/default/dropbear
sed -i 's/DROPBEAR_PORT=22/DROPBEAR_PORT=109/' /etc/default/dropbear
systemctl enable dropbear
systemctl restart dropbear

# Segundo Dropbear en 143
/usr/sbin/dropbear -p 143 -W 65536
cat > /etc/systemd/system/dropbear143.service << 'EOF'
[Unit]
Description=Dropbear 143
After=network.target
[Service]
ExecStart=/usr/sbin/dropbear -F -p 143 -W 65536
Restart=on-failure
[Install]
WantedBy=multi-user.target
EOF
systemctl enable dropbear143
systemctl restart dropbear143

echo -e "${YELLOW}[5/12] Configurando Stunnel (447, 777)...${NC}"
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
systemctl enable stunnel4
systemctl restart stunnel4

echo -e "${YELLOW}[6/12] Instalando BadVPN (7100-7300)...${NC}"
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

echo -e "${YELLOW}[7/12] Instalando WebSocket (2090)...${NC}"
cat > /usr/local/bin/oxgi-ws << 'EOFWS'
#!/usr/bin/env python3
import socket
import threading

def handle_client(client_socket):
    try:
        ssh_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        ssh_socket.connect(('127.0.0.1', 22))
        
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
        t1.start()
        t2.start()
        t1.join()
        t2.join()
    except Exception as e:
        pass
    finally:
        try:
            client_socket.close()
            ssh_socket.close()
        except:
            pass

def main():
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(('0.0.0.0', 2090))
    server.listen(100)
    
    while True:
        client, addr = server.accept()
        t = threading.Thread(target=handle_client, args=(client,))
        t.start()

if __name__ == '__main__':
    main()
EOFWS
chmod +x /usr/local/bin/oxgi-ws

cat > /etc/systemd/system/oxgi-ws.service << 'EOF'
[Unit]
Description=OXGI WebSocket
After=network.target
[Service]
Type=simple
ExecStart=/usr/bin/python3 /usr/local/bin/oxgi-ws
Restart=on-failure
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable oxgi-ws
systemctl restart oxgi-ws

echo -e "${YELLOW}[8/12] Instalando Xray...${NC}"
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install 2>/dev/null
UUID=$(cat /proc/sys/kernel/random/uuid)
echo "$UUID" > /etc/oxgi/xray_uuid

cat > /etc/xray/config.json << EOFXRAY
{
  "log": {"loglevel": "warning"},
  "inbounds": [
    {
      "port": 10000,
      "protocol": "vmess",
      "settings": {"clients": [{"id": "${UUID}", "level": 0}]},
      "streamSettings": {"network": "ws", "wsSettings": {"path": "/vmess"}}
    },
    {
      "port": 10001,
      "protocol": "vless",
      "settings": {"clients": [{"id": "${UUID}", "level": 0}], "decryption": "none"},
      "streamSettings": {"network": "ws", "wsSettings": {"path": "/vless"}}
    },
    {
      "port": 10002,
      "protocol": "trojan",
      "settings": {"clients": [{"password": "${UUID}", "level": 0}]},
      "streamSettings": {"network": "ws", "wsSettings": {"path": "/trojan"}}
    },
    {
      "port": 10003,
      "protocol": "shadowsocks",
      "settings": {"clients": [{"password": "${UUID}", "method": "aes-256-gcm"}]},
      "streamSettings": {"network": "ws", "wsSettings": {"path": "/sodosok"}}
    }
  ],
  "outbounds": [{"protocol": "freedom"}]
}
EOFXRAY
systemctl enable xray
systemctl restart xray

echo -e "${YELLOW}[9/12] Configurando Nginx (80, 81, 443)...${NC}"
cat > /etc/nginx/sites-available/oxgi << EOF
map \$http_upgrade \$connection_upgrade { default upgrade; '' close; }

server {
    listen 80; server_name ${DOMAIN};
    location / {
        proxy_pass http://127.0.0.1:2090;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header Host \$host;
        proxy_set_header Sec-WebSocket-Version \$http_sec_websocket_version;
        proxy_set_header Sec-WebSocket-Key \$http_sec_websocket_key;
        proxy_buffering off;
    }
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
    location / {
        proxy_pass http://127.0.0.1:2090;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header Host \$host;
        proxy_set_header Sec-WebSocket-Version \$http_sec_websocket_version;
        proxy_set_header Sec-WebSocket-Key \$http_sec_websocket_key;
        proxy_buffering off;
    }
    location /vmess { proxy_pass http://127.0.0.1:10000; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection \$connection_upgrade; proxy_buffering off; }
    location /vless { proxy_pass http://127.0.0.1:10001; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection \$connection_upgrade; proxy_buffering off; }
    location /trojan { proxy_pass http://127.0.0.1:10002; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection \$connection_upgrade; proxy_buffering off; }
    location /sodosok { proxy_pass http://127.0.0.1:10003; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection \$connection_upgrade; proxy_buffering off; }
}

server {
    listen 81; server_name 127.0.0.1 localhost;
    root /home/vps/public_html;
    location / {
        index index.html index.htm index.php;
        try_files \$uri \$uri/ /index.php?\$args;
    }
    location ~ \.php\$ {
        include /etc/nginx/fastcgi_params;
        fastcgi_pass 127.0.0.1:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }
}
EOF

ln -sf /etc/nginx/sites-available/oxgi /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl restart nginx

echo -e "${YELLOW}[10/12] Instalando SSL...${NC}"
apt install -y certbot python3-certbot-nginx
systemctl stop nginx
certbot certonly --standalone -d "$DOMAIN" --non-interactive --agree-tos --email admin@${DOMAIN#*.} 2>/dev/null
systemctl start nginx

echo -e "${YELLOW}[11/12] Configurando Fail2Ban...${NC}"
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
maxretry = 5
[sshd]
enabled = true
port = 22,109,143
EOF
systemctl enable fail2ban
systemctl restart fail2ban

echo -e "${YELLOW}[12/12] Configurando auto-reboot y módulos...${NC}"
echo "0 5 * * * /sbin/reboot" | crontab -

mkdir -p /usr/local/oxgi/modules

cat > /usr/local/oxgi/modules/users.sh << 'EOFUSER'
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
EOFUSER
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

add_ss() {
    clear; echo -e "${CYAN}SHADOWSOCKS${NC}\n"
    read -p "Nombre: " name; [[ -z "$name" ]] && return
    read -p "Días: " days; [[ ! "$days" =~ ^[0-9]+$ ]] && return
    exp=$(date -d "+$days days" +"%Y-%m-%d")
    echo "${name}:${UUID}:shadowsocks:${exp}" >> "$DB"
    echo -e "\n${GREEN}$name${NC} - Exp: $exp"
    echo "ss://$(echo "aes-256-gcm:${UUID}@${DOMAIN}:443" | base64 -w0)#${name}"
    read -p "ENTER"
}

lista() {
    clear; echo -e "${CYAN}V2RAY USERS${NC}\n"
    [[ ! -s "$DB" ]] && { echo "Sin usuarios"; read -p "ENTER"; return; }
    printf "%-15s %-15s %-20s\n" "USER" "TYPE" "EXPIRA"
    while IFS=':' read -r n u t e; do printf "%-15s %-15s %-20s\n" "$n" "$t" "$e"; done < "$DB"
    read -p "ENTER"
}

while true; do
    clear; echo -e "${CYAN}V2RAY MANAGER${NC}\n"
    echo "[1] VMESS [2] VLESS [3] TROJAN [4] Shadowsocks [5] Lista [0] Salir"
    read -p "Opción: " o
    case $o in 1) add_vmess;; 2) add_vless;; 3) add_trojan;; 4) add_ss;; 5) lista;; 0) exit 0;; esac
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

cat > /usr/local/oxgi/modules/websocket.sh << 'EFOFWS'
#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
while true; do
    clear; echo -e "${GREEN}WEBSOCKET MANAGER${NC}\n"
    echo "[1] Restart [2] Stop [3] Start [4] Status [5] Logs [0] Exit"
    read -p "Option: " o
    case $o in
        1) systemctl restart oxgi-ws; echo "Done"; read -p "ENTER";;
        2) systemctl stop oxgi-ws; echo "Done"; read -p "ENTER";;
        3) systemctl start oxgi-ws; echo "Done"; read -p "ENTER";;
        4) systemctl status oxgi-ws --no-pager; read -p "ENTER";;
        5) journalctl -u oxgi-ws -n 30 --no-pager; read -p "ENTER";;
        0) exit 0;;
    esac
done
EFOFWS
chmod +x /usr/local/oxgi/modules/websocket.sh

cat > /usr/local/bin/oxgi << 'EOFMENU'
#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

while true; do
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║      ${GREEN}OXGI VPS MANAGER${NC}${CYAN}                     ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${CYAN}[01]${NC} SSH Users"
    echo -e "${CYAN}[02]${NC} V2Ray Users"
    echo -e "${CYAN}[03]${NC} Nginx"
    echo -e "${CYAN}[04]${NC} WebSocket"
    echo -e "${CYAN}[05]${NC} Restart All"
    echo -e "${CYAN}[06]${NC} Services Status"
    echo -e "${CYAN}[07]${NC} Active Ports"
    echo -e "${CYAN}[08]${NC} System Info"
    echo -e "${RED}[00]${NC} Exit"
    read -p "Option: " opt
    case $opt in
        1) bash /usr/local/oxgi/modules/users.sh ;;
        2) bash /usr/local/oxgi/modules/v2ray.sh ;;
        3) bash /usr/local/oxgi/modules/nginx.sh ;;
        4) bash /usr/local/oxgi/modules/websocket.sh ;;
        5) systemctl restart nginx oxgi-ws dropbear dropbear143 stunnel4 xray; echo -e "${GREEN}Done${NC}"; read -p "ENTER" ;;
        6) systemctl status nginx oxgi-ws dropbear dropbear143 stunnel4 xray --no-pager -l; read -p "ENTER" ;;
        7) netstat -tlnp | grep -E ':(22|80|109|143|443|447|777|7100|7200|7300|2090|81)'; read -p "ENTER" ;;
        8) echo "Uptime:"; uptime; echo; free -h; echo; df -h; read -p "ENTER" ;;
        0) clear; exit 0 ;;
    esac
done
EOFMENU
chmod +x /usr/local/bin/oxgi

clear
echo -e "${GREEN}════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}   INSTALACIÓN COMPLETADA${NC}"
echo -e "${GREEN}════════════════════════════════════════════╝${NC}"
echo -e "SSH: ${GREEN}22${NC} | WS: ${GREEN}80,443${NC} | Dropbear: ${GREEN}109,143${NC}"
echo -e "Stunnel: ${GREEN}447,777${NC} | BadVPN: ${GREEN}7100-7300${NC}"
echo -e "WebSocket: ${GREEN}2090${NC} | Nginx: ${GREEN}81${NC}"
echo -e "XRAY: ${GREEN}80,443${NC}"
echo ""
echo -e "${YELLOW}Ejecuta:${NC} ${GREEN}oxgi${NC}"
