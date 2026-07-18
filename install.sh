#!/bin/bash
# ==========================================
# OXGI VPS SCRIPT - BASED ON BLUEBLUE
# ==========================================

if [[ $EUID -ne 0 ]]; then
   echo "Please run as root"
   exit 1
fi

export DEBIAN_FRONTEND=noninteractive
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

clear
echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║      ${GREEN}OXGI VPS INSTALLER${NC}${CYAN}                  ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
echo ""

# Get domain
read -p "Enter your domain: " DOMAIN
if [[ -z "$DOMAIN" ]]; then
    echo -e "${RED}Domain is required${NC}"
    exit 1
fi

mkdir -p /etc/oxgi
echo "$DOMAIN" > /etc/oxgi/domain.conf

# Update system
echo -e "${YELLOW}[1/12] Updating system...${NC}"
apt update -y
apt upgrade -y

# Install basic packages
echo -e "${YELLOW}[2/12] Installing basic packages...${NC}"
apt install -y nginx python3 python3-pip curl wget unzip jq bc \
    openssl net-tools screen cmake g++ make cron \
    fail2ban vnstat certbot python3-certbot-nginx

# Install Dropbear
echo -e "${YELLOW}[3/12] Installing Dropbear...${NC}"
apt install -y dropbear
sed -i 's/NO_START=1/NO_START=0/' /etc/default/dropbear
sed -i 's/DROPBEAR_PORT=22/DROPBEAR_PORT=109/' /etc/default/dropbear
systemctl enable dropbear
systemctl restart dropbear

# Second Dropbear on port 143
/usr/sbin/dropbear -p 143 -W 65536
cat > /etc/systemd/system/dropbear143.service << 'EOF'
[Unit]
Description=Dropbear SSH Server Port 143
After=network.target

[Service]
Type=forking
ExecStart=/usr/sbin/dropbear -F -p 143 -W 65536
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable dropbear143
systemctl restart dropbear143

# Install Stunnel4
echo -e "${YELLOW}[4/12] Installing Stunnel...${NC}"
apt install -y stunnel4
mkdir -p /etc/stunnel
openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
    -subj "/C=ID/ST=Jakarta/L=Jakarta/O=OXGI/CN=localhost" \
    -keyout /etc/stunnel/stunnel.key \
    -out /etc/stunnel/stunnel.crt 2>/dev/null
cat /etc/stunnel/stunnel.crt /etc/stunnel/stunnel.key > /etc/stunnel/stunnel.pem
chmod 600 /etc/stunnel/stunnel.pem

cat > /etc/stunnel/stunnel.conf << EOF
cert = /etc/stunnel/stunnel.pem
client = no
socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1
compression = zstd

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

# Install BadVPN
echo -e "${YELLOW}[5/12] Installing BadVPN...${NC}"
mkdir -p /root/badvpn
cd /root/badvpn
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
Description=BadVPN UDPGW ${PORT}
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/badvpn-udpgw --listen-addr 127.0.0.1:${PORT} --max-clients 1000 --max-connections-for-client 10
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    systemctl enable badvpn-${PORT}
    systemctl restart badvpn-${PORT}
done

# Install WebSocket (ws-stunnel style)
echo -e "${YELLOW}[6/12] Installing WebSocket...${NC}"
pip3 install websockets

cat > /usr/local/bin/ws-stunnel << 'EOFWS'
#!/usr/bin/env python3
import asyncio
import websockets
import socket
import threading

def forward_data(src, dst):
    try:
        while True:
            data = src.recv(4096)
            if not data:
                break
            dst.sendall(data)
    except:
        pass

async def handle_client(websocket, path):
    try:
        ssh_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        ssh_socket.connect(('127.0.0.1', 22))
        
        loop = asyncio.get_event_loop()
        
        def ws_to_ssh():
            async def get_data():
                async for msg in websocket:
                    ssh_socket.sendall(msg)
            asyncio.run_coroutine_threadsafe(get_data(), loop)
        
        def ssh_to_ws():
            while True:
                try:
                    data = ssh_socket.recv(4096)
                    if not data:
                        break
                    asyncio.run_coroutine_threadsafe(websocket.send(data), loop)
                except:
                    break
        
        t1 = threading.Thread(target=ws_to_ssh)
        t2 = threading.Thread(target=ssh_to_ws)
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
            websocket.close()
        except:
            pass

async def main():
    async with websockets.serve(handle_client, '0.0.0.0', 2090):
        await asyncio.Future()

if __name__ == '__main__':
    asyncio.run(main())
EOFWS

chmod +x /usr/local/bin/ws-stunnel

cat > /etc/systemd/system/ws-stunnel.service << 'EOF'
[Unit]
Description=WebSocket Stunnel
After=network.target ssh.service

[Service]
Type=simple
User=root
ExecStart=/usr/bin/python3 /usr/local/bin/ws-stunnel
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable ws-stunnel
systemctl restart ws-stunnel

# Install Xray
echo -e "${YELLOW}[7/12] Installing Xray...${NC}"
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install 2>/dev/null

UUID=$(cat /proc/sys/kernel/random/uuid)
echo "$UUID" > /etc/oxgi/xray_uuid

cat > /etc/xray/config.json << EOFXRAY
{
  "log": {
    "loglevel": "warning",
    "error": "/var/log/xray/error.log",
    "access": "/var/log/xray/access.log"
  },
  "inbounds": [
    {
      "port": 10000,
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "${UUID}",
            "level": 0,
            "alterId": 0
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/vmess"
        }
      }
    },
    {
      "port": 10001,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${UUID}",
            "level": 0
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/vless"
        }
      }
    },
    {
      "port": 10002,
      "protocol": "trojan",
      "settings": {
        "clients": [
          {
            "password": "${UUID}",
            "level": 0
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/trojan"
        }
      }
    },
    {
      "port": 10003,
      "protocol": "shadowsocks",
      "settings": {
        "clients": [
          {
            "method": "aes-256-gcm",
            "password": "${UUID}"
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/sodosok"
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
EOFXRAY

systemctl enable xray
systemctl restart xray

# Configure Nginx
echo -e "${YELLOW}[8/12] Configuring Nginx...${NC}"
cat > /etc/nginx/nginx.conf << 'EOFNGINX'
user www-data;
worker_processes 1;
pid /var/run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
    multi_accept on;
    worker_connections 1024;
}

http {
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    server_tokens off;
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;
    gzip on;
    gzip_vary on;
    gzip_comp_level 5;
    client_max_body_size 32M;
    client_header_buffer_size 8m;
    large_client_header_buffers 8 8m;
    
    # Cloudflare IP Ranges
    set_real_ip_from 204.93.240.0/24;
    set_real_ip_from 204.93.177.0/24;
    set_real_ip_from 199.27.128.0/21;
    set_real_ip_from 173.245.48.0/20;
    set_real_ip_from 103.21.244.0/22;
    set_real_ip_from 103.22.200.0/22;
    set_real_ip_from 103.31.4.0/22;
    set_real_ip_from 141.101.64.0/18;
    set_real_ip_from 108.162.192.0/18;
    set_real_ip_from 190.93.240.0/20;
    set_real_ip_from 188.114.96.0/20;
    set_real_ip_from 197.234.240.0/22;
    set_real_ip_from 198.41.128.0/17;
    real_ip_header CF-Connecting-IP;

    include /etc/nginx/conf.d/*.conf;
}
EOFNGINX

cat > /etc/nginx/conf.d/websocket.conf << EOFWS
map \$http_upgrade \$connection_upgrade {
    default upgrade;
    '' close;
}

# HTTP - Port 80
server {
    listen 80;
    server_name ${DOMAIN};
    
    # SSH WebSocket
    location / {
        proxy_pass http://127.0.0.1:2090;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Sec-WebSocket-Version \$http_sec_websocket_version;
        proxy_set_header Sec-WebSocket-Key \$http_sec_websocket_key;
        proxy_connect_timeout 86400s;
        proxy_send_timeout 86400s;
        proxy_read_timeout 86400s;
        proxy_buffering off;
        proxy_request_buffering off;
    }
    
    # Xray Vmess
    location /vmess {
        proxy_pass http://127.0.0.1:10000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header Host \$host;
        proxy_buffering off;
        proxy_cache_bypass \$http_upgrade;
    }
    
    # Xray Vless
    location /vless {
        proxy_pass http://127.0.0.1:10001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header Host \$host;
        proxy_buffering off;
        proxy_cache_bypass \$http_upgrade;
    }
    
    # Xray Trojan
    location /trojan {
        proxy_pass http://127.0.0.1:10002;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header Host \$host;
        proxy_buffering off;
        proxy_cache_bypass \$http_upgrade;
    }
    
    # Xray Shadowsocks
    location /sodosok {
        proxy_pass http://127.0.0.1:10003;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header Host \$host;
        proxy_buffering off;
        proxy_cache_bypass \$http_upgrade;
    }
}

# HTTPS - Port 443
server {
    listen 443 ssl http2;
    server_name ${DOMAIN};
    
    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # SSH SSL WebSocket
    location / {
        proxy_pass http://127.0.0.1:2090;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Sec-WebSocket-Version \$http_sec_websocket_version;
        proxy_set_header Sec-WebSocket-Key \$http_sec_websocket_key;
        proxy_connect_timeout 86400s;
        proxy_send_timeout 86400s;
        proxy_read_timeout 86400s;
        proxy_buffering off;
        proxy_request_buffering off;
    }
    
    # Xray Vmess
    location /vmess {
        proxy_pass http://127.0.0.1:10000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header Host \$host;
        proxy_buffering off;
        proxy_cache_bypass \$http_upgrade;
    }
    
    # Xray Vless
    location /vless {
        proxy_pass http://127.0.0.1:10001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header Host \$host;
        proxy_buffering off;
        proxy_cache_bypass \$http_upgrade;
    }
    
    # Xray Trojan
    location /trojan {
        proxy_pass http://127.0.0.1:10002;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header Host \$host;
        proxy_buffering off;
        proxy_cache_bypass \$http_upgrade;
    }
    
    # Xray Shadowsocks
    location /sodosok {
        proxy_pass http://127.0.0.1:10003;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header Host \$host;
        proxy_buffering off;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOFWS

cat > /etc/nginx/conf.d/vps.conf << 'EOFVPS'
server {
    listen 81;
    server_name 127.0.0.1 localhost;
    access_log /var/log/nginx/vps-access.log;
    error_log /var/log/nginx/vps-error.log error;
    root /home/vps/public_html;

    location / {
        index index.html index.htm index.php;
        try_files $uri $uri/ /index.php?$args;
    }

    location ~ \.php$ {
        include /etc/nginx/fastcgi_params;
        fastcgi_pass 127.0.0.1:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    }
}
EOFVPS

rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl restart nginx

# Install SSL Certificate
echo -e "${YELLOW}[9/12] Installing SSL Certificate...${NC}"
systemctl stop nginx
certbot certonly --standalone -d "$DOMAIN" --non-interactive --agree-tos --email admin@${DOMAIN#*.} 2>/dev/null
systemctl start nginx

# Configure Fail2Ban
echo -e "${YELLOW}[10/12] Configuring Fail2Ban...${NC}"
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5
backend = auto

[sshd]
enabled = true
port = 22,109,143
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
EOF

systemctl enable fail2ban
systemctl restart fail2ban

# Configure Auto-Reboot
echo -e "${YELLOW}[11/12] Configuring Auto-Reboot...${NC}"
echo "0 5 * * * /sbin/reboot" | crontab -

# Create OXGI Modules
echo -e "${YELLOW}[12/12] Creating OXGI Modules...${NC}"
mkdir -p /usr/local/oxgi/modules

# ============================================
# MODULE: users.sh (SSH User Management)
# ============================================
cat > /usr/local/oxgi/modules/users.sh << 'EOFUSER'
#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

DB_FILE="/etc/oxgi/ssh_users.db"
mkdir -p /etc/oxgi
touch "$DB_FILE"

create_user() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║      CREATE SSH/WEBSOCKET ACCOUNT          ║${NC}"
    echo -e "${CYAN}════════════════════════════════════════════╝${NC}"
    echo ""
    
    read -p "Username: " username
    if [[ ! "$username" =~ ^[a-zA-Z0-9_]+$ ]] || [[ ${#username} -lt 3 ]]; then
        echo -e "${RED}Invalid username (3-16 chars, letters/numbers only)${NC}"
        read -p "Press ENTER to continue..."
        return
    fi
    
    if id "$username" &>/dev/null; then
        echo -e "${RED}User already exists${NC}"
        read -p "Press ENTER to continue..."
        return
    fi
    
    read -p "Password (leave blank for auto): " password
    if [[ -z "$password" ]]; then
        password=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9' | head -c 10)
        echo -e "${YELLOW}Auto-generated password: ${GREEN}$password${NC}"
    fi
    
    echo ""
    echo -e "${CYAN}Time Unit:${NC}"
    echo -e "  [1] Minutes  [2] Hours  [3] Days  [4] Months  [5] Years"
    read -p "Select: " unit_opt
    
    case $unit_opt in
        1) unit="minutes"; mult=60 ;;
        2) unit="hours"; mult=3600 ;;
        3) unit="days"; mult=86400 ;;
        4) unit="months"; mult=2592000 ;;
        5) unit="years"; mult=31536000 ;;
        *) echo -e "${RED}Invalid option${NC}"; read -p "Press ENTER..."; return ;;
    esac
    
    read -p "Quantity: " qty
    if [[ ! "$qty" =~ ^[0-9]+$ ]] || [[ "$qty" -le 0 ]]; then
        echo -e "${RED}Invalid number${NC}"
        read -p "Press ENTER..."
        return
    fi
    
    read -p "Max devices: " max_dev
    if [[ ! "$max_dev" =~ ^[0-9]+$ ]] || [[ "$max_dev" -le 0 ]]; then
        echo -e "${RED}Invalid number${NC}"
        read -p "Press ENTER..."
        return
    fi
    
    add_seconds=$((qty * mult))
    now_epoch=$(date +%s)
    exp_epoch=$((now_epoch + add_seconds))
    exp_datetime=$(date -d "@$exp_epoch" "+%Y-%m-%d %H:%M:%S")
    exp_date=$(echo "$exp_datetime" | cut -d' ' -f1)
    
    useradd -e "$exp_date" -s /bin/false -M "$username"
    echo "$username:$password" | chpasswd
    echo "${username}:${exp_epoch}:${exp_datetime}:${max_dev}" >> "$DB_FILE"
    
    echo ""
    echo -e "${GREEN}✅ User created successfully!${NC}"
    echo -e "Username : ${GREEN}$username${NC}"
    echo -e "Password : ${GREEN}$password${NC}"
    echo -e "Expires  : ${GREEN}$exp_datetime${NC}"
    echo -e "Max Dev  : ${GREEN}$max_dev${NC}"
    echo -e "Ports    : ${GREEN}22, 80, 109, 143, 443, 447, 777${NC}"
    echo ""
    read -p "Press ENTER to continue..."
}

delete_user() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║      DELETE USER                           ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
    echo ""
    
    read -p "Username to delete: " username
    
    if ! id "$username" &>/dev/null; then
        echo -e "${RED}User does not exist${NC}"
        read -p "Press ENTER to continue..."
        return
    fi
    
    userdel -r "$username" 2>/dev/null
    sed -i "/^${username}:/d" "$DB_FILE"
    
    echo -e "${GREEN}User deleted successfully${NC}"
    read -p "Press ENTER to continue..."
}

list_users() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║      REGISTERED USERS                      ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
    echo ""
    
    if [[ ! -s "$DB_FILE" ]]; then
        echo -e "${YELLOW}No users registered${NC}"
    else
        printf "${CYAN}%-15s %-25s %-10s${NC}\n" "USERNAME" "EXPIRES" "MAX DEV"
        echo "─────────────────────────────────────────────────────"
        while IFS=':' read -r user exp_epoch exp_datetime max_dev; do
            printf "${GREEN}%-15s ${YELLOW}%-25s ${CYAN}%-10s${NC}\n" "$user" "$exp_datetime" "$max_dev"
        done < "$DB_FILE"
    fi
    echo ""
    read -p "Press ENTER to continue..."
}

online_users() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║      ONLINE USERS                          ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${YELLOW}Currently connected users:${NC}"
    who | awk '{print $1}' | sort | uniq -c | sort -rn
    echo ""
    read -p "Press ENTER to continue..."
}

# Main Menu
while true; do
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║      ${GREEN}OXGI USER MANAGER${NC}${CYAN}                   ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}[01]${NC} Create SSH/WebSocket User"
    echo -e "${CYAN}[02]${NC} Delete User"
    echo -e "${CYAN}[03]${NC} List Users"
    echo -e "${CYAN}[04]${NC} Online Users"
    echo -e "${CYAN}[05]${NC} Renew User"
    echo -e "${CYAN}[06]${NC} Change Password"
    echo ""
    echo -e "${RED}[00]${NC} Back"
    echo ""
    read -p "Select option: " opt
    
    case $opt in
        1) create_user ;;
        2) delete_user ;;
        3) list_users ;;
        4) online_users ;;
        5) echo -e "${YELLOW}Coming soon...${NC}"; read -p "Press ENTER..." ;;
        6) echo -e "${YELLOW}Coming soon...${NC}"; read -p "Press ENTER..." ;;
        0) clear; exit 0 ;;
        *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
    esac
done
EOFUSER
chmod +x /usr/local/oxgi/modules/users.sh

# ============================================
# MODULE: v2ray.sh (V2Ray Management)
# ============================================
cat > /usr/local/oxgi/modules/v2ray.sh << 'EOFV2RAY'
#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

source /etc/oxgi/config.conf 2>/dev/null || DOMAIN=$(cat /etc/oxgi/domain.conf)
UUID=$(cat /etc/oxgi/xray_uuid)
DB_FILE="/etc/oxgi/v2ray_users.db"
mkdir -p /etc/oxgi
touch "$DB_FILE"

add_vmess() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║      CREATE VMESS ACCOUNT                  ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
    echo ""
    
    read -p "User name: " name
    [[ -z "$name" ]] && { echo -e "${RED}Name required${NC}"; read -p "Press ENTER..."; return; }
    
    read -p "Days to expire: " days
    [[ ! "$days" =~ ^[0-9]+$ ]] && { echo -e "${RED}Invalid number${NC}"; read -p "Press ENTER..."; return; }
    
    exp_date=$(date -d "+$days days" +"%Y-%m-%d")
    echo "${name}:${UUID}:vmess:${exp_date}" >> "$DB_FILE"
    
    echo ""
    echo -e "${GREEN}✅ VMESS created!${NC}"
    echo -e "User  : ${GREEN}$name${NC}"
    echo -e "UUID  : ${GREEN}$UUID${NC}"
    echo -e "Expire: ${GREEN}$exp_date${NC}"
    echo ""
    echo -e "${CYAN}Configuration:${NC}"
    config=$(echo '{"v":"2","ps":"'$name'","add":"'$DOMAIN'","port":"443","id":"'$UUID'","aid":"0","net":"ws","type":"none","host":"'$DOMAIN'","path":"/vmess","tls":"tls"}' | base64 -w0)
    echo "vmess://$config"
    echo ""
    read -p "Press ENTER to continue..."
}

add_vless() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║      CREATE VLESS ACCOUNT                  ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
    echo ""
    
    read -p "User name: " name
    [[ -z "$name" ]] && { echo -e "${RED}Name required${NC}"; read -p "Press ENTER..."; return; }
    
    read -p "Days to expire: " days
    [[ ! "$days" =~ ^[0-9]+$ ]] && { echo -e "${RED}Invalid number${NC}"; read -p "Press ENTER..."; return; }
    
    exp_date=$(date -d "+$days days" +"%Y-%m-%d")
    echo "${name}:${UUID}:vless:${exp_date}" >> "$DB_FILE"
    
    echo ""
    echo -e "${GREEN}✅ VLESS created!${NC}"
    echo -e "User  : ${GREEN}$name${NC}"
    echo -e "UUID  : ${GREEN}$UUID${NC}"
    echo -e "Expire: ${GREEN}$exp_date${NC}"
    echo ""
    echo -e "${CYAN}Configuration:${NC}"
    echo "vless://${UUID}@${DOMAIN}:443?encryption=none&security=tls&type=ws&path=/vless&host=${DOMAIN}#${name}"
    echo ""
    read -p "Press ENTER to continue..."
}

add_trojan() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║      CREATE TROJAN ACCOUNT                 ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
    echo ""
    
    read -p "User name: " name
    [[ -z "$name" ]] && { echo -e "${RED}Name required${NC}"; read -p "Press ENTER..."; return; }
    
    read -p "Days to expire: " days
    [[ ! "$days" =~ ^[0-9]+$ ]] && { echo -e "${RED}Invalid number${NC}"; read -p "Press ENTER..."; return; }
    
    exp_date=$(date -d "+$days days" +"%Y-%m-%d")
    password=$(echo "$name$UUID" | md5sum | awk '{print $1}')
    echo "${name}:${password}:trojan:${exp_date}" >> "$DB_FILE"
    
    echo ""
    echo -e "${GREEN}✅ TROJAN created!${NC}"
    echo -e "User    : ${GREEN}$name${NC}"
    echo -e "Password: ${GREEN}$password${NC}"
    echo -e "Expire  : ${GREEN}$exp_date${NC}"
    echo ""
    echo -e "${CYAN}Configuration:${NC}"
    echo "trojan://${password}@${DOMAIN}:443?security=tls&type=ws&path=/trojan&sni=${DOMAIN}#${name}"
    echo ""
    read -p "Press ENTER to continue..."
}

add_shadowsocks() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║      CREATE SHADOWSOCKS ACCOUNT            ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
    echo ""
    
    read -p "User name: " name
    [[ -z "$name" ]] && { echo -e "${RED}Name required${NC}"; read -p "Press ENTER..."; return; }
    
    read -p "Days to expire: " days
    [[ ! "$days" =~ ^[0-9]+$ ]] && { echo -e "${RED}Invalid number${NC}"; read -p "Press ENTER..."; return; }
    
    exp_date=$(date -d "+$days days" +"%Y-%m-%d")
    echo "${name}:${UUID}:shadowsocks:${exp_date}" >> "$DB_FILE"
    
    echo ""
    echo -e "${GREEN}✅ SHADOWSOCKS created!${NC}"
    echo -e "User  : ${GREEN}$name${NC}"
    echo -e "Pass  : ${GREEN}$UUID${NC}"
    echo -e "Expire: ${GREEN}$exp_date${NC}"
    echo ""
    echo -e "${CYAN}Configuration:${NC}"
    config=$(echo "aes-256-gcm:${UUID}@${DOMAIN}:443" | base64 -w0)
    echo "ss://$config#${name}"
    echo ""
    read -p "Press ENTER to continue..."
}

list_users() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║      V2RAY USERS                           ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
    echo ""
    
    if [[ ! -s "$DB_FILE" ]]; then
        echo -e "${YELLOW}No V2Ray users${NC}"
    else
        printf "${CYAN}%-15s %-15s %-20s${NC}\n" "USER" "TYPE" "EXPIRES"
        echo "─────────────────────────────────────────────────────"
        while IFS=':' read -r name uuid type exp_date; do
            printf "${GREEN}%-15s ${YELLOW}%-15s ${CYAN}%-20s${NC}\n" "$name" "$type" "$exp_date"
        done < "$DB_FILE"
    fi
    echo ""
    read -p "Press ENTER to continue..."
}

# Main Menu
while true; do
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║      ${GREEN}OXGI V2RAY MANAGER${NC}${CYAN}                  ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}[01]${NC} Create VMESS"
    echo -e "${CYAN}[02]${NC} Create VLESS"
    echo -e "${CYAN}[03]${NC} Create TROJAN"
    echo -e "${CYAN}[04]${NC} Create SHADOWSOCKS"
    echo -e "${CYAN}[05]${NC} List Users"
    echo -e "${CYAN}[06]${NC} Delete User"
    echo ""
    echo -e "${RED}[00]${NC} Back"
    echo ""
    read -p "Select option: " opt
    
    case $opt in
        1) add_vmess ;;
        2) add_vless ;;
        3) add_trojan ;;
        4) add_shadowsocks ;;
        5) list_users ;;
        6) echo -e "${YELLOW}Coming soon...${NC}"; read -p "Press ENTER..." ;;
        0) clear; exit 0 ;;
        *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
    esac
done
EOFV2RAY
chmod +x /usr/local/oxgi/modules/v2ray.sh

# ============================================
# MODULE: nginx.sh
# ============================================
cat > /usr/local/oxgi/modules/nginx.sh << 'EOFNGINX'
#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

while true; do
    clear
    echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║      NGINX MANAGER                         ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}[1]${NC} Restart Nginx"
    echo -e "${GREEN}[2]${NC} Stop Nginx"
    echo -e "${GREEN}[3]${NC} Start Nginx"
    echo -e "${GREEN}[4]${NC} Status"
    echo -e "${GREEN}[5]${NC} Test Configuration"
    echo -e "${GREEN}[6]${NC} View Error Log"
    echo ""
    echo -e "${RED}[0]${NC} Back"
    echo ""
    read -p "Option: " opt
    
    case $opt in
        1) systemctl restart nginx; echo -e "${GREEN}Done${NC}"; read -p "Press ENTER..." ;;
        2) systemctl stop nginx; echo -e "${GREEN}Done${NC}"; read -p "Press ENTER..." ;;
        3) systemctl start nginx; echo -e "${GREEN}Done${NC}"; read -p "Press ENTER..." ;;
        4) systemctl status nginx --no-pager -l; read -p "Press ENTER..." ;;
        5) nginx -t; read -p "Press ENTER..." ;;
        6) tail -50 /var/log/nginx/error.log; read -p "Press ENTER..." ;;
        0) clear; exit 0 ;;
        *) echo -e "${RED}Invalid${NC}"; sleep 1 ;;
    esac
done
EOFNGINX
chmod +x /usr/local/oxgi/modules/nginx.sh

# ============================================
# MODULE: websocket.sh
# ============================================
cat > /usr/local/oxgi/modules/websocket.sh << 'EOFWS'
#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

while true; do
    clear
    echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║      WEBSOCKET MANAGER                     ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}[1]${NC} Restart WebSocket"
    echo -e "${GREEN}[2]${NC} Stop WebSocket"
    echo -e "${GREEN}[3]${NC} Start WebSocket"
    echo -e "${GREEN}[4]${NC} Status"
    echo -e "${GREEN}[5]${NC} View Logs"
    echo -e "${GREEN}[6]${NC} Check Port 2090"
    echo ""
    echo -e "${RED}[0]${NC} Back"
    echo ""
    read -p "Option: " opt
    
    case $opt in
        1) systemctl restart ws-stunnel; echo -e "${GREEN}Done${NC}"; read -p "Press ENTER..." ;;
        2) systemctl stop ws-stunnel; echo -e "${GREEN}Done${NC}"; read -p "Press ENTER..." ;;
        3) systemctl start ws-stunnel; echo -e "${GREEN}Done${NC}"; read -p "Press ENTER..." ;;
        4) systemctl status ws-stunnel --no-pager -l; read -p "Press ENTER..." ;;
        5) journalctl -u ws-stunnel --no-pager -n 50; read -p "Press ENTER..." ;;
        6) netstat -tlnp | grep 2090; read -p "Press ENTER..." ;;
        0) clear; exit 0 ;;
        *) echo -e "${RED}Invalid${NC}"; sleep 1 ;;
    esac
done
EOFWS
chmod +x /usr/local/oxgi/modules/websocket.sh

# ============================================
# MAIN MENU: oxgi
# ============================================
cat > /usr/local/bin/oxgi << 'EOFMENU'
#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

while true; do
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║      ${GREEN}OXGI VPS MANAGER${NC}${CYAN}                    ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}[01]${NC} SSH/WebSocket User Management"
    echo -e "${CYAN}[02]${NC} V2Ray User Management"
    echo -e "${CYAN}[03]${NC} Nginx Management"
    echo -e "${CYAN}[04]${NC} WebSocket Management"
    echo -e "${CYAN}[05]${NC} Restart All Services"
    echo -e "${CYAN}[06]${NC} Services Status"
    echo -e "${CYAN}[07]${NC} Active Ports"
    echo -e "${CYAN}[08]${NC} System Information"
    echo ""
    echo -e "${RED}[00]${NC} Exit"
    echo ""
    read -p "Select option: " opt
    
    case $opt in
        1) bash /usr/local/oxgi/modules/users.sh ;;
        2) bash /usr/local/oxgi/modules/v2ray.sh ;;
        3) bash /usr/local/oxgi/modules/nginx.sh ;;
        4) bash /usr/local/oxgi/modules/websocket.sh ;;
        5) systemctl restart nginx ws-stunnel dropbear dropbear143 stunnel4 xray fail2ban; echo -e "${GREEN}All services restarted${NC}"; read -p "Press ENTER..." ;;
        6) systemctl status nginx ws-stunnel dropbear dropbear143 stunnel4 xray --no-pager -l; read -p "Press ENTER..." ;;
        7) netstat -tlnp | grep -E ':(22|80|109|143|443|447|777|7100|7200|7300|2090|81)'; read -p "Press ENTER..." ;;
        8) echo -e "${CYAN}System Info:${NC}"; uname -a; echo; uptime; echo; free -h; echo; df -h; read -p "Press ENTER..." ;;
        0) clear; echo -e "${GREEN}Goodbye!${NC}"; exit 0 ;;
        *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
    esac
done
EOFMENU
chmod +x /usr/local/bin/oxgi

# Final Summary
clear
echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║      ${BOLD}OXGI VPS - INSTALLATION COMPLETE${NC}${GREEN}   ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "${CYAN}Service & Port${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "OpenSSH           : ${GREEN}22${NC}"
echo -e "SSH Websocket     : ${GREEN}80${NC}"
echo -e "SSH SSL Websocket : ${GREEN}443${NC}"
echo -e "Stunnel           : ${GREEN}447, 777${NC}"
echo -e "Dropbear          : ${GREEN}109, 143${NC}"
echo -e "BadVPN            : ${GREEN}7100-7300${NC}"
echo -e "Nginx             : ${GREEN}81${NC}"
echo -e "XRAY Vmess        : ${GREEN}80, 443${NC}"
echo -e "XRAY Vless        : ${GREEN}80, 443${NC}"
echo -e "XRAY Trojan       : ${GREEN}80, 443${NC}"
echo -e "XRAY Sodosok      : ${GREEN}80, 443${NC}"
echo ""
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "${CYAN}Features${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "Fail2Ban          : ${GREEN}[ON]${NC}"
echo -e "Auto-Reboot       : ${GREEN}[ON] - 5:00 AM${NC}"
echo -e "Auto Delete Expired: ${GREEN}[ON]${NC}"
echo ""
echo -e "${YELLOW}Type 'oxgi' to manage your VPS${NC}"
echo ""
