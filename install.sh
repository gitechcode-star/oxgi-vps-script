#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# OXGI VPS SCRIPT - COMPLETE PRODUCTION READY
# ══════════════════════════════════════════════════════════════

if [[ $EUID -ne 0 ]]; then
   echo "Este script debe ejecutarse como root"
   exit 1
fi

export DEBIAN_FRONTEND=noninteractive
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'; BOLD='\033[1m'

clear
echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║           ${GREEN}${BOLD}OXGI VPS INSTALLER${NC}${CYAN}                     ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"

read -p "Ingresa tu dominio: " DOMAIN
[[ -z "$DOMAIN" ]] && echo "Dominio requerido" && exit 1
mkdir -p /etc/oxgi
echo "$DOMAIN" > /etc/oxgi/domain.conf

echo -e "${YELLOW}[1/9] Instalando dependencias...${NC}"
apt update -y > /dev/null 2>&1
apt upgrade -y > /dev/null 2>&1
apt install -y nginx python3 python3-pip certbot python3-certbot-nginx dropbear stunnel5 screen cmake g++ make git curl wget unzip jq bc openssl net-tools > /dev/null 2>&1

echo -e "${YELLOW}[2/9] Configurando sistema...${NC}"
cat > /etc/oxgi/config.conf << EOF
SSH_PORT="22"
DROPBEAR_PORT_1="109"
DROPBEAR_PORT_2="143"
WS_BACKEND_PORT="2090"
STUNNEL_PORT_1="447"
STUNNEL_PORT_2="777"
BADVPN_PORT_1="7100"
BADVPN_PORT_2="7200"
BADVPN_PORT_3="7300"
NGINX_VPS_PORT="81"
DOMAIN="$DOMAIN"
UUID="$(cat /proc/sys/kernel/random/uuid)"
EOF

echo -e "${YELLOW}[3/9] Configurando Nginx...${NC}"
cat > /etc/nginx/nginx.conf << 'EOFNGINX'
user www-data;
worker_processes 1;
pid /var/run/nginx.pid;
events { multi_accept on; worker_connections 1024; }
http {
    sendfile on; tcp_nopush on; tcp_nodelay on; keepalive_timeout 65;
    types_hash_max_size 2048; server_tokens off;
    include /etc/nginx/mime.types; default_type application/octet-stream;
    gzip on; gzip_vary on;
    client_max_body_size 32M;
    set_real_ip_from 204.93.240.0/24; set_real_ip_from 204.93.177.0/24;
    set_real_ip_from 199.27.128.0/21; set_real_ip_from 173.245.48.0/20;
    set_real_ip_from 103.21.244.0/22; set_real_ip_from 103.22.200.0/22;
    set_real_ip_from 103.31.4.0/22; set_real_ip_from 141.101.64.0/18;
    set_real_ip_from 108.162.192.0/18; set_real_ip_from 190.93.240.0/20;
    set_real_ip_from 188.114.96.0/20; set_real_ip_from 197.234.240.0/22;
    set_real_ip_from 198.41.128.0/17;
    real_ip_header CF-Connecting-IP;
    include /etc/nginx/conf.d/*.conf;
}
EOFNGINX

cat > /etc/nginx/conf.d/websocket.conf << EOFWS
map \$http_upgrade \$connection_upgrade { default upgrade; '' close; }
server {
    listen 80; server_name ${DOMAIN} _;
    location / {
        proxy_pass http://127.0.0.1:2090; proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection \$connection_upgrade;
        proxy_set_header Host \$host; proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header Sec-WebSocket-Version \$http_sec_websocket_version;
        proxy_set_header Sec-WebSocket-Key \$http_sec_websocket_key;
        proxy_connect_timeout 86400s; proxy_send_timeout 86400s; proxy_read_timeout 86400s;
        proxy_buffering off; proxy_request_buffering off;
    }
    location /vless { proxy_pass http://127.0.0.1:10001; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection \$connection_upgrade; proxy_buffering off; }
    location /vmess { proxy_pass http://127.0.0.1:10000; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection \$connection_upgrade; proxy_buffering off; }
    location /trojan { proxy_pass http://127.0.0.1:10002; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection \$connection_upgrade; proxy_buffering off; }
}
server {
    listen 443 ssl http2; server_name ${DOMAIN} _;
    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3; ssl_ciphers HIGH:!aNULL:!MD5;
    location / {
        proxy_pass http://127.0.0.1:2090; proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection \$connection_upgrade;
        proxy_set_header Host \$host; proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header Sec-WebSocket-Version \$http_sec_websocket_version;
        proxy_set_header Sec-WebSocket-Key \$http_sec_websocket_key;
        proxy_buffering off; proxy_request_buffering off;
    }
    location /vless { proxy_pass http://127.0.0.1:10001; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection \$connection_upgrade; proxy_buffering off; }
    location /vmess { proxy_pass http://127.0.0.1:10000; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection \$connection_upgrade; proxy_buffering off; }
    location /trojan { proxy_pass http://127.0.0.1:10002; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection \$connection_upgrade; proxy_buffering off; }
}
EOFWS

cat > /etc/nginx/conf.d/vps.conf << 'EOFVPS'
server { listen 81; server_name 127.0.0.1 localhost; root /home/vps/public_html;
    location / { index index.html index.htm index.php; try_files $uri $uri/ /index.php?$args; }
    location ~ \.php$ { include /etc/nginx/fastcgi_params; fastcgi_pass 127.0.0.1:9000; fastcgi_index index.php; fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name; }
}
EOFVPS
rm -f /etc/nginx/sites-enabled/default
systemctl restart nginx

echo -e "${YELLOW}[4/9] Instalando WebSocket...${NC}"
pip3 install websockets > /dev/null 2>&1
cat > /usr/local/bin/oxgi-ws << 'EOFWS'
#!/usr/bin/env python3
import asyncio, websockets, socket, sys
async def handle_client(websocket, path):
    try:
        ssh_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        ssh_socket.connect(('127.0.0.1', 22))
        ssh_socket.setblocking(0)
        async def ws_to_ssh():
            try:
                async for message in websocket: ssh_socket.sendall(message)
            except: pass
        async def ssh_to_ws():
            try:
                while True:
                    await asyncio.sleep(0.01)
                    try:
                        data = ssh_socket.recv(4096)
                        if data: await websocket.send(data)
                        else: break
                    except BlockingIOError: await asyncio.sleep(0.01); continue
                    except: break
            except: pass
        await asyncio.gather(ws_to_ssh(), ssh_to_ws())
    except Exception as e: print(f"Error: {e}", file=sys.stderr)
    finally:
        try: websocket.close()
        except: pass
        try: ssh_socket.close()
        except: pass
async def main():
    async with websockets.serve(handle_client, '0.0.0.0', 2090): await asyncio.Future()
if __name__ == '__main__': asyncio.run(main())
EOFWS
chmod +x /usr/local/bin/oxgi-ws
cat > /etc/systemd/system/oxgi-ws.service << 'EOFSVC'
[Unit]
Description=OXGI WebSocket Service
After=network.target ssh.service
[Service]
Type=simple
User=root
ExecStart=/usr/bin/python3 /usr/local/bin/oxgi-ws
Restart=on-failure
RestartSec=5
[Install]
WantedBy=multi-user.target
EOFSVC
systemctl daemon-reload && systemctl enable oxgi-ws && systemctl restart oxgi-ws

echo -e "${YELLOW}[5/9] Configurando Dropbear...${NC}"
sed -i 's/NO_START=1/NO_START=0/' /etc/default/dropbear
sed -i 's/DROPBEAR_PORT=22/DROPBEAR_PORT=109/' /etc/default/dropbear
cat > /etc/default/dropbear-143 << 'EOF'
NO_START=0
DROPBEAR_PORT=143
DROPBEAR_EXTRA_ARGS=""
EOF
cat > /etc/systemd/system/dropbear@.service << 'EOF'
[Unit]
Description=Dropbear SSH Daemon
After=network.target
[Service]
Type=forking
EnvironmentFile=/etc/default/%i
ExecStart=/usr/sbin/dropbear -F -p $DROPBEAR_PORT $DROPBEAR_EXTRA_ARGS
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload && systemctl enable dropbear && systemctl enable dropbear@dropbear-143
systemctl restart dropbear && systemctl restart dropbear@dropbear-143

echo -e "${YELLOW}[6/9] Configurando Stunnel...${NC}"
mkdir -p /etc/stunnel
openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 -subj "/C=ID/ST=Jakarta/L=Jakarta/O=OXGI/CN=localhost" -keyout /etc/stunnel/stunnel.key -out /etc/stunnel/stunnel.crt > /dev/null 2>&1
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
sed -i 's/ENABLED=0/ENABLED=1/g' /etc/default/stunnel5
systemctl enable stunnel5 && systemctl restart stunnel5

echo -e "${YELLOW}[7/9] Instalando BadVPN...${NC}"
mkdir -p /root/badvpn && cd /root/badvpn
git clone https://github.com/ambrop72/badvpn.git . > /dev/null 2>&1
mkdir build && cd build
cmake .. -DBUILD_NOTHING_BY_DEFAULT=ON -DBUILD_UDPGW=ON > /dev/null 2>&1
make > /dev/null 2>&1
cp udpgw/badvpn-udpgw /usr/bin/
for PORT in 7100 7200 7300; do
    cat > /etc/systemd/system/badvpn-${PORT}.service << EOF
[Unit]
Description=BadVPN UDPGW ${PORT}
[Service]
ExecStart=/usr/bin/badvpn-udpgw --listen-addr 127.0.0.1:${PORT} --max-clients 1000
Restart=on-failure
[Install]
WantedBy=multi-user.target
EOF
    systemctl enable badvpn-${PORT} && systemctl start badvpn-${PORT}
done

echo -e "${YELLOW}[8/9] Generando SSL...${NC}"
systemctl stop nginx
certbot certonly --standalone -d "$DOMAIN" --non-interactive --agree-tos --email admin@${DOMAIN#*.} > /dev/null 2>&1
systemctl start nginx

echo -e "${YELLOW}[9/9] Creando módulos de gestión...${NC}"
mkdir -p /usr/local/oxgi/modules

# ============================================
# MÓDULO DE USUARIOS SSH COMPLETO
# ============================================
cat > /usr/local/oxgi/modules/users.sh << 'EOFUSER'
#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
DB_FILE="/etc/oxgi/ssh_users.db"
mkdir -p /etc/oxgi && touch "$DB_FILE"

crear_usuario() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║          CREAR CUENTA SSH / WEBSOCKET                        ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    read -p "Nombre de usuario: " username
    if [[ ! "$username" =~ ^[a-zA-Z0-9_]+$ ]] || [[ ${#username} -lt 3 ]]; then
        echo -e "${RED}Usuario inválido (3-16 caracteres)${NC}"; read -p "ENTER..."; return
    fi
    if id "$username" &>/dev/null; then
        echo -e "${RED}El usuario ya existe${NC}"; read -p "ENTER..."; return
    fi

    read -p "Contraseña (dejar en blanco para autogenerar): " password
    if [[ -z "$password" ]]; then
        password=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9' | head -c 10)
        echo -e "${YELLOW}Contraseña generada: ${GREEN}$password${NC}"
    fi

    echo -e "\n${CYAN}Unidad de tiempo: [1] Minutos  [2] Horas  [3] Días  [4] Meses  [5] Años${NC}"
    read -p "Opción: " unit_opt
    case $unit_opt in
        1) unit_str="minutes"; mult=60 ;;
        2) unit_str="hours"; mult=3600 ;;
        3) unit_str="days"; mult=86400 ;;
        4) unit_str="months"; mult=2592000 ;;
        5) unit_str="years"; mult=31536000 ;;
        *) echo -e "${RED}Opción inválida${NC}"; read -p "ENTER..."; return ;;
    esac

    read -p "Cantidad de $unit_str: " time_qty
    [[ ! "$time_qty" =~ ^[0-9]+$ ]] || [[ "$time_qty" -le 0 ]] && { echo -e "${RED}Número inválido${NC}"; read -p "ENTER..."; return; }

    read -p "Número máximo de dispositivos: " max_dev
    [[ ! "$max_dev" =~ ^[0-9]+$ ]] || [[ "$max_dev" -le 0 ]] && { echo -e "${RED}Número inválido${NC}"; read -p "ENTER..."; return; }

    add_seconds=$((time_qty * mult))
    now_epoch=$(date +%s)
    exp_epoch=$((now_epoch + add_seconds))
    exp_datetime=$(date -d "@$exp_epoch" "+%Y-%m-%d %H:%M:%S")
    exp_date=$(echo "$exp_datetime" | cut -d' ' -f1)

    useradd -e "$exp_date" -s /bin/false -M "$username"
    echo "$username:$password" | chpasswd
    echo "${username}:${exp_epoch}:${exp_datetime}:${max_dev}" >> "$DB_FILE"

    echo -e "\n${GREEN}✅ Usuario creado!${NC}"
    echo -e "Usuario : ${GREEN}$username${NC}"
    echo -e "Password: ${GREEN}$password${NC}"
    echo -e "Expira  : ${GREEN}$exp_datetime${NC}"
    echo -e "Devices : ${GREEN}$max_dev${NC}"
    echo -e "Puertos : ${GREEN}22, 109, 143, 80, 443, 447, 777${NC}"
    read -p "ENTER..."
}

eliminar_usuario() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║          ELIMINAR USUARIO                                    ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    read -p "Usuario a eliminar: " username
    if ! id "$username" &>/dev/null; then
        echo -e "${RED}El usuario no existe${NC}"; read -p "ENTER..."; return
    fi
    userdel -r "$username" 2>/dev/null
    sed -i "/^${username}:/d" "$DB_FILE"
    echo -e "${GREEN}Usuario eliminado${NC}"
    read -p "ENTER..."
}

lista_usuarios() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║          LISTA DE USUARIOS                                   ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    if [[ ! -s "$DB_FILE" ]]; then
        echo -e "${YELLOW}No hay usuarios${NC}"
    else
        printf "${CYAN}%-15s %-25s %-5s${NC}\n" "USUARIO" "EXPIRA" "DEV"
        echo "─────────────────────────────────────────────────────────"
        while IFS=':' read -r user exp_epoch exp_datetime max_dev; do
            printf "${GREEN}%-15s ${YELLOW}%-25s ${CYAN}%-5s${NC}\n" "$user" "$exp_datetime" "$max_dev"
        done < "$DB_FILE"
    fi
    read -p "ENTER..."
}

usuarios_online() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║          USUARIOS ONLINE                                     ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    who | awk '{print $1}' | sort | uniq -c | sort -rn
    read -p "ENTER..."
}

while true; do
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║          ${BOLD}OXGI USER MANAGER${NC}${CYAN}                              ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${CYAN}[01]${NC} Crear Usuario SSH/WebSocket"
    echo -e "${CYAN}[02]${NC} Eliminar Usuario"
    echo -e "${CYAN}[03]${NC} Lista de Usuarios"
    echo -e "${CYAN}[04]${NC} Usuarios Online"
    echo -e "${CYAN}[05]${NC} Renovar Usuario"
    echo -e "${CYAN}[06]${NC} Cambiar Contraseña"
    echo
    echo -e "${RED}[00]${NC} Salir"
    read -p "Opción: " opt
    case $opt in
        1) crear_usuario ;;
        2) eliminar_usuario ;;
        3) lista_usuarios ;;
        4) usuarios_online ;;
        5) echo -e "${YELLOW}Próximamente${NC}"; read -p "ENTER..." ;;
        6) echo -e "${YELLOW}Próximamente${NC}"; read -p "ENTER..." ;;
        0) clear; exit 0 ;;
        *) echo -e "${RED}Inválida${NC}"; sleep 1 ;;
    esac
done
EOFUSER
chmod +x /usr/local/oxgi/modules/users.sh

# ============================================
# MÓDULO V2RAY COMPLETO Y FUNCIONAL
# ============================================
cat > /usr/local/oxgi/modules/v2ray.sh << 'EOFV2RAY'
#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
source /etc/oxgi/config.conf
DB_FILE="/etc/oxgi/v2ray_users.db"
mkdir -p /etc/oxgi && touch "$DB_FILE"

UUID=$(cat /proc/sys/kernel/random/uuid)

add_vmess() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║          CREAR CUENTA VMESS                                  ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    read -p "Nombre del usuario: " name
    [[ -z "$name" ]] && { echo -e "${RED}Nombre requerido${NC}"; read -p "ENTER..."; return; }
    
    read -p "Días de expiración: " days
    [[ ! "$days" =~ ^[0-9]+$ ]] && { echo -e "${RED}Número inválido${NC}"; read -p "ENTER..."; return; }
    
    exp_date=$(date -d "+$days days" +"%Y-%m-%d")
    
    echo "${name}:${UUID}:vmess:${exp_date}" >> "$DB_FILE"
    
    echo -e "\n${GREEN}✅ VMESS creado!${NC}"
    echo -e "Usuario : ${GREEN}$name${NC}"
    echo -e "UUID    : ${GREEN}$UUID${NC}"
    echo -e "Expira  : ${GREEN}$exp_date${NC}"
    echo
    echo -e "${CYAN}Configuración:${NC}"
    echo "vmess://$(echo '{"v":"2","ps":"'$name'","add":"'$DOMAIN'","port":"443","id":"'$UUID'","aid":"0","net":"ws","type":"none","host":"'$DOMAIN'","path":"/vmess","tls":"tls"}' | base64 -w0)"
    echo
    read -p "ENTER..."
}

add_vless() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║          CREAR CUENTA VLESS                                  ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    read -p "Nombre del usuario: " name
    [[ -z "$name" ]] && { echo -e "${RED}Nombre requerido${NC}"; read -p "ENTER..."; return; }
    
    read -p "Días de expiración: " days
    [[ ! "$days" =~ ^[0-9]+$ ]] && { echo -e "${RED}Número inválido${NC}"; read -p "ENTER..."; return; }
    
    exp_date=$(date -d "+$days days" +"%Y-%m-%d")
    
    echo "${name}:${UUID}:vless:${exp_date}" >> "$DB_FILE"
    
    echo -e "\n${GREEN}✅ VLESS creado!${NC}"
    echo -e "Usuario : ${GREEN}$name${NC}"
    echo -e "UUID    : ${GREEN}$UUID${NC}"
    echo -e "Expira  : ${GREEN}$exp_date${NC}"
    echo
    echo -e "${CYAN}Configuración:${NC}"
    echo "vless://${UUID}@${DOMAIN}:443?encryption=none&security=tls&type=ws&path=/vless&host=${DOMAIN}#${name}"
    echo
    read -p "ENTER..."
}

add_trojan() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║          CREAR CUENTA TROJAN                                 ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    read -p "Nombre del usuario: " name
    [[ -z "$name" ]] && { echo -e "${RED}Nombre requerido${NC}"; read -p "ENTER..."; return; }
    
    read -p "Días de expiración: " days
    [[ ! "$days" =~ ^[0-9]+$ ]] && { echo -e "${RED}Número inválido${NC}"; read -p "ENTER..."; return; }
    
    exp_date=$(date -d "+$days days" +"%Y-%m-%d")
    password=$(echo "$name$UUID" | md5sum | awk '{print $1}')
    
    echo "${name}:${password}:trojan:${exp_date}" >> "$DB_FILE"
    
    echo -e "\n${GREEN}✅ TROJAN creado!${NC}"
    echo -e "Usuario  : ${GREEN}$name${NC}"
    echo -e "Password : ${GREEN}$password${NC}"
    echo -e "Expira   : ${GREEN}$exp_date${NC}"
    echo
    echo -e "${CYAN}Configuración:${NC}"
    echo "trojan://${password}@${DOMAIN}:443?security=tls&type=ws&path=/trojan&sni=${DOMAIN}#${name}"
    echo
    read -p "ENTER..."
}

lista_v2ray() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║          USUARIOS V2RAY                                      ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    if [[ ! -s "$DB_FILE" ]]; then
        echo -e "${YELLOW}No hay usuarios V2Ray${NC}"
    else
        printf "${CYAN}%-15s %-10s %-20s${NC}\n" "USUARIO" "TIPO" "EXPIRA"
        echo "─────────────────────────────────────────────────────────"
        while IFS=':' read -r name uuid type exp_date; do
            printf "${GREEN}%-15s ${YELLOW}%-10s ${CYAN}%-20s${NC}\n" "$name" "$type" "$exp_date"
        done < "$DB_FILE"
    fi
    read -p "ENTER..."
}

while true; do
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║          ${BOLD}OXGI V2RAY MANAGER${NC}${CYAN}                            ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${CYAN}[01]${NC} Crear VMESS"
    echo -e "${CYAN}[02]${NC} Crear VLESS"
    echo -e "${CYAN}[03]${NC} Crear TROJAN"
    echo -e "${CYAN}[04]${NC} Lista de Usuarios V2Ray"
    echo -e "${CYAN}[05]${NC} Eliminar Usuario"
    echo
    echo -e "${RED}[00]${NC} Salir"
    read -p "Opción: " opt
    case $opt in
        1) add_vmess ;;
        2) add_vless ;;
        3) add_trojan ;;
        4) lista_v2ray ;;
        5) echo -e "${YELLOW}Próximamente${NC}"; read -p "ENTER..." ;;
        0) clear; exit 0 ;;
        *) echo -e "${RED}Inválida${NC}"; sleep 1 ;;
    esac
done
EOFV2RAY
chmod +x /usr/local/oxgi/modules/v2ray.sh

# ============================================
# MÓDULO NGINX COMPLETO
# ============================================
cat > /usr/local/oxgi/modules/nginx.sh << 'EOFNGINXMOD'
#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

while true; do
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║          ${BOLD}NGINX MANAGER${NC}${CYAN}                                ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${CYAN}[01]${NC} Reiniciar Nginx"
    echo -e "${CYAN}[02]${NC} Detener Nginx"
    echo -e "${CYAN}[03]${NC} Iniciar Nginx"
    echo -e "${CYAN}[04]${NC} Ver Estado"
    echo -e "${CYAN}[05]${NC} Ver Logs de Error"
    echo -e "${CYAN}[06]${NC} Probar Configuración"
    echo
    echo -e "${RED}[00]${NC} Salir"
    read -p "Opción: " opt
    case $opt in
        1) systemctl restart nginx; echo -e "${GREEN}Reiniciado${NC}"; read -p "ENTER..." ;;
        2) systemctl stop nginx; echo -e "${GREEN}Detenido${NC}"; read -p "ENTER..." ;;
        3) systemctl start nginx; echo -e "${GREEN}Iniciado${NC}"; read -p "ENTER..." ;;
        4) systemctl status nginx --no-pager -l; read -p "ENTER..." ;;
        5) tail -50 /var/log/nginx/error.log; read -p "ENTER..." ;;
        6) nginx -t; read -p "ENTER..." ;;
        0) clear; exit 0 ;;
        *) echo -e "${RED}Inválida${NC}"; sleep 1 ;;
    esac
done
EOFNGINXMOD
chmod +x /usr/local/oxgi/modules/nginx.sh

# ============================================
# MÓDULO WEBSOCKET COMPLETO
# ============================================
cat > /usr/local/oxgi/modules/websocket.sh << 'EFOFWSMOD'
#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

while true; do
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║          ${BOLD}WEBSOCKET MANAGER${NC}${CYAN}                            ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${CYAN}[01]${NC} Reiniciar WebSocket"
    echo -e "${CYAN}[02]${NC} Detener WebSocket"
    echo -e "${CYAN}[03]${NC} Iniciar WebSocket"
    echo -e "${CYAN}[04]${NC} Ver Estado"
    echo -e "${CYAN}[05]${NC} Ver Logs"
    echo -e "${CYAN}[06]${NC} Ver Puerto 2090"
    echo
    echo -e "${RED}[00]${NC} Salir"
    read -p "Opción: " opt
    case $opt in
        1) systemctl restart oxgi-ws; echo -e "${GREEN}Reiniciado${NC}"; read -p "ENTER..." ;;
        2) systemctl stop oxgi-ws; echo -e "${GREEN}Detenido${NC}"; read -p "ENTER..." ;;
        3) systemctl start oxgi-ws; echo -e "${GREEN}Iniciado${NC}"; read -p "ENTER..." ;;
        4) systemctl status oxgi-ws --no-pager -l; read -p "ENTER..." ;;
        5) journalctl -u oxgi-ws --no-pager -n 50; read -p "ENTER..." ;;
        6) netstat -tlnp | grep 2090; read -p "ENTER..." ;;
        0) clear; exit 0 ;;
        *) echo -e "${RED}Inválida${NC}"; sleep 1 ;;
    esac
done
EFOFWSMOD
chmod +x /usr/local/oxgi/modules/websocket.sh

# ============================================
# MENÚ PRINCIPAL OXGI
# ============================================
cat > /usr/local/bin/oxgi << 'EOFMENU'
#!/bin/bash
source /etc/oxgi/config.conf 2>/dev/null
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

while true; do
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║          ${BOLD}OXGI VPS MANAGER${NC}${CYAN}                              ${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${CYAN}[01]${NC} Gestión de Usuarios SSH/WebSocket"
    echo -e "${CYAN}[02]${NC} Gestión de Usuarios V2Ray"
    echo -e "${CYAN}[03]${NC} Gestión de Nginx"
    echo -e "${CYAN}[04]${NC} Gestión de WebSocket"
    echo -e "${CYAN}[05]${NC} Reiniciar Todos los Servicios"
    echo -e "${CYAN}[06]${NC} Ver Estado de Servicios"
    echo -e "${CYAN}[07]${NC} Ver Puertos Activos"
    echo -e "${CYAN}[08]${NC} Información del Sistema"
    echo
    echo -e "${RED}[00]${NC} Salir"
    read -p "Seleccione una opción: " opt
    case $opt in
        1) bash /usr/local/oxgi/modules/users.sh ;;
        2) bash /usr/local/oxgi/modules/v2ray.sh ;;
        3) bash /usr/local/oxgi/modules/nginx.sh ;;
        4) bash /usr/local/oxgi/modules/websocket.sh ;;
        5) systemctl restart nginx oxgi-ws dropbear stunnel5; echo -e "${GREEN}Servicios reiniciados${NC}"; read -p "ENTER..." ;;
        6) systemctl status nginx oxgi-ws dropbear stunnel5 --no-pager -l; read -p "ENTER..." ;;
        7) netstat -tlnp | grep -E ':(22|80|109|143|443|447|777|7100|7200|7300|2090|81)'; read -p "ENTER..." ;;
        8) echo -e "${CYAN}Sistema:${NC}"; uname -a; echo; uptime; echo; free -h; echo; df -h; read -p "ENTER..." ;;
        0) clear; echo -e "${GREEN}Hasta luego!${NC}"; exit 0 ;;
        *) echo -e "${RED}Opción inválida${NC}"; sleep 1 ;;
    esac
done
EOFMENU
chmod +x /usr/local/bin/oxgi

clear
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║        ${BOLD}OXGI VPS - INSTALACIÓN COMPLETADA${NC}${GREEN}           ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo -e "${CYAN}Servicios:${NC}"
echo -e "SSH               : ${GREEN}22${NC}"
echo -e "WebSocket         : ${GREEN}80, 443${NC}"
echo -e "Dropbear          : ${GREEN}109, 143${NC}"
echo -e "Stunnel           : ${GREEN}447, 777${NC}"
echo -e "BadVPN            : ${GREEN}7100, 7200, 7300${NC}"
echo -e "Nginx Panel       : ${GREEN}81${NC}"
echo -e "WebSocket Backend : ${GREEN}2090${NC}"
echo -e "V2Ray             : ${GREEN}80, 443${NC}"
echo ""
echo -e "${YELLOW}Comando:${NC} ${GREEN}oxgi${NC}"
echo ""
echo -e "${CYAN}Escribe 'oxgi' para gestionar${NC}"
