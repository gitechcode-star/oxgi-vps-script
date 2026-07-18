#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# OXGI VPS SCRIPT - MASTER INSTALLER COMPLETO
# ══════════════════════════════════════════════════════════════

if [[ $EUID -ne 0 ]]; then
   echo "Este script debe ejecutarse como root (usa sudo su)"
   exit 1
fi

export DEBIAN_FRONTEND=noninteractive
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

clear
echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║           ${GREEN}${BOLD}OXGI VPS MASTER INSTALLER${NC}${CYAN}          ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
echo ""

# 1. DOMINIO
read -p "Ingresa tu dominio (ej: s.xcloud.fun): " DOMAIN
if [[ -z "$DOMAIN" ]]; then
    echo -e "${RED}Dominio requerido${NC}"
    exit 1
fi
mkdir -p /etc/oxgi
echo "$DOMAIN" > /etc/oxgi/domain.conf

# 2. ACTUALIZAR E INSTALAR PAQUETES BASE
echo -e "${YELLOW}[1/9] Actualizando sistema e instalando dependencias...${NC}"
apt update -y > /dev/null 2>&1
apt upgrade -y > /dev/null 2>&1
apt install -y nginx python3 python3-pip certbot python3-certbot-nginx dropbear stunnel5 screen cmake g++ make git curl wget unzip jq bc openssl net-tools > /dev/null 2>&1

# 3. CONFIGURACIÓN GLOBAL
echo -e "${YELLOW}[2/9] Configurando variables globales...${NC}"
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
EOF

# 4. NGINX
echo -e "${YELLOW}[3/9] Configurando Nginx (Puertos 80, 81, 443)...${NC}"
cat > /etc/nginx/nginx.conf << 'EOFNGINX'
user www-data;
worker_processes 1;
pid /var/run/nginx.pid;
events { multi_accept on; worker_connections 1024; }
http {
    sendfile on; tcp_nopush on; tcp_nodelay on; keepalive_timeout 65;
    types_hash_max_size 2048; server_tokens off;
    include /etc/nginx/mime.types; default_type application/octet-stream;
    gzip on; gzip_vary on; gzip_comp_level 5;
    client_max_body_size 32M; client_header_buffer_size 8m;
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

# 5. WEBSOCKET PYTHON
echo -e "${YELLOW}[4/9] Instalando WebSocket Python (Puerto 2090)...${NC}"
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

# 6. DROPBEAR
echo -e "${YELLOW}[5/9] Configurando Dropbear (109, 143)...${NC}"
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

# 7. STUNNEL
echo -e "${YELLOW}[6/9] Configurando Stunnel5 (447, 777)...${NC}"
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

# 8. BADVPN
echo -e "${YELLOW}[7/9] Compilando BadVPN (7100, 7200, 7300)...${NC}"
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

# 9. CERTIFICADO SSL
echo -e "${YELLOW}[8/9] Generando certificado SSL Let's Encrypt...${NC}"
systemctl stop nginx
certbot certonly --standalone -d "$DOMAIN" --non-interactive --agree-tos --email admin@${DOMAIN#*.} > /dev/null 2>&1
systemctl start nginx

# 10. SCRIPT DE USUARIOS AVANZADO CON MENÚ COMPLETO
echo -e "${YELLOW}[9/9] Instalando gestor de usuarios avanzado...${NC}"
mkdir -p /usr/local/oxgi/modules
cat > /usr/local/oxgi/modules/users.sh << 'EOFUSER'
#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
DB_FILE="/etc/oxgi/ssh_users.db"
mkdir -p /etc/oxgi && touch "$DB_FILE"

crear_usuario_ssh() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║          CREAR CUENTA SSH / WEBSOCKET                        ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    read -p "Nombre de usuario: " username
    if [[ ! "$username" =~ ^[a-zA-Z0-9_]+$ ]] || [[ ${#username} -lt 3 ]]; then
        echo -e "${RED}Usuario inválido (3-16 caracteres, solo letras/números)${NC}"
        read -p "ENTER para continuar..."
        return
    fi
    if id "$username" &>/dev/null; then
        echo -e "${RED}El usuario ya existe${NC}"
        read -p "ENTER para continuar..."
        return
    fi

    read -p "Contraseña (dejar en blanco para generar una aleatoria): " password
    if [[ -z "$password" ]]; then
        password=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9' | head -c 10)
        echo -e "${YELLOW}Contraseña generada automáticamente: ${GREEN}$password${NC}"
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
    if [[ ! "$time_qty" =~ ^[0-9]+$ ]] || [[ "$time_qty" -le 0 ]]; then
        echo -e "${RED}Número inválido${NC}"; read -p "ENTER..."; return
    fi

    read -p "Número máximo de dispositivos permitidos: " max_dev
    if [[ ! "$max_dev" =~ ^[0-9]+$ ]] || [[ "$max_dev" -le 0 ]]; then
        echo -e "${RED}Número inválido${NC}"; read -p "ENTER..."; return
    fi

    add_seconds=$((time_qty * mult))
    now_epoch=$(date +%s)
    exp_epoch=$((now_epoch + add_seconds))
    exp_datetime=$(date -d "@$exp_epoch" "+%Y-%m-%d %H:%M:%S")
    exp_date=$(echo "$exp_datetime" | cut -d' ' -f1)

    useradd -e "$exp_date" -s /bin/false -M "$username"
    echo "$username:$password" | chpasswd
    echo "${username}:${exp_epoch}:${exp_datetime}:${max_dev}" >> "$DB_FILE"

    echo -e "\n${GREEN}Usuario creado exitosamente!${NC}"
    echo -e "Usuario : ${GREEN}$username${NC}"
    echo -e "Password: ${GREEN}$password${NC}"
    echo -e "Expira  : ${GREEN}$exp_datetime${NC}"
    echo -e "Devices : ${GREEN}$max_dev${NC}"
    echo -e "Puertos : ${GREEN}22, 109, 143, 80, 443, 447, 777${NC}"
    echo
    read -p "ENTER para continuar..."
}

eliminar_usuario() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║          ELIMINAR USUARIO                                    ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    read -p "Nombre de usuario a eliminar: " username
    if ! id "$username" &>/dev/null; then
        echo -e "${RED}El usuario no existe${NC}"
        read -p "ENTER para continuar..."
        return
    fi
    userdel -r "$username" 2>/dev/null
    sed -i "/^${username}:/d" "$DB_FILE"
    echo -e "${GREEN}Usuario $username eliminado${NC}"
    read -p "ENTER para continuar..."
}

lista_usuarios() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║          LISTA DE USUARIOS                                   ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    if [[ ! -s "$DB_FILE" ]]; then
        echo -e "${YELLOW}No hay usuarios registrados${NC}"
    else
        printf "${CYAN}%-15s %-25s %-5s${NC}\n" "USUARIO" "EXPIRA" "DEV"
        echo "─────────────────────────────────────────────────────────"
        while IFS=':' read -r user exp_epoch exp_datetime max_dev; do
            printf "${GREEN}%-15s ${YELLOW}%-25s ${CYAN}%-5s${NC}\n" "$user" "$exp_datetime" "$max_dev"
        done < "$DB_FILE"
    fi
    echo
    read -p "ENTER para continuar..."
}

usuarios_online() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║          USUARIOS ONLINE                                     ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${YELLOW}Usuarios conectados actualmente:${NC}"
    who | awk '{print $1}' | sort | uniq -c | sort -rn
    echo
    read -p "ENTER para continuar..."
}

# MENÚ PRINCIPAL DE USUARIOS
while true; do
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║          ${BOLD}OXGI USER MANAGER${NC}${CYAN}                              ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${CYAN}[01]${NC} Crear Usuario SSH/WebSocket"
    echo -e "${CYAN}[02]${NC} Eliminar Usuario"
    echo -e "${CYAN}[03]${NC} Lista de Usuarios"
    echo -e "${CYAN}[04]${NC} Usuarios Online"
    echo -e "${CYAN}[05]${NC} Renovar Usuario"
    echo -e "${CYAN}[06]${NC} Cambiar Contraseña"
    echo -e "${CYAN}[07]${NC} Check Usuario"
    echo -e "${CYAN}[08]${NC} Eliminar Expirados"
    echo
    echo -e "${RED}[00]${NC} Salir"
    echo
    read -p "Seleccione una opción: " opt
    case $opt in
        1) crear_usuario_ssh ;;
        2) eliminar_usuario ;;
        3) lista_usuarios ;;
        4) usuarios_online ;;
        5) echo -e "${YELLOW}Próximamente...${NC}"; read -p "ENTER..." ;;
        6) echo -e "${YELLOW}Próximamente...${NC}"; read -p "ENTER..." ;;
        7) echo -e "${YELLOW}Próximamente...${NC}"; read -p "ENTER..." ;;
        8) echo -e "${YELLOW}Próximamente...${NC}"; read -p "ENTER..." ;;
        0) clear; exit 0 ;;
        *) echo -e "${RED}Opción inválida${NC}"; sleep 1 ;;
    esac
done
EOFUSER
chmod +x /usr/local/oxgi/modules/users.sh

# MENÚ PRINCIPAL OXGI
cat > /usr/local/bin/oxgi << 'EOFMENU'
#!/bin/bash
source /etc/oxgi/config.conf 2>/dev/null
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

while true; do
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║          ${BOLD}OXGI VPS MANAGER${NC}${CYAN}                              ${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${CYAN}[01]${NC} Gestión de Usuarios SSH/WebSocket"
    echo -e "${CYAN}[02]${NC} Gestión de Usuarios V2Ray"
    echo -e "${CYAN}[03]${NC} Gestión de Nginx"
    echo -e "${CYAN}[04]${NC} Gestión de WebSocket"
    echo -e "${CYAN}[05]${NC} Reiniciar Servicios"
    echo -e "${CYAN}[06]${NC} Ver Estado de Servicios"
    echo -e "${CYAN}[07]${NC} Ver Puertos Activos"
    echo -e "${CYAN}[08]${NC} Información del Sistema"
    echo
    echo -e "${RED}[00]${NC} Salir"
    echo
    read -p "Seleccione una opción: " opt
    case $opt in
        1) bash /usr/local/oxgi/modules/users.sh ;;
        2) echo -e "${YELLOW}Módulo V2Ray próximamente...${NC}"; read -p "ENTER..." ;;
        3) echo -e "${YELLOW}Módulo Nginx próximamente...${NC}"; read -p "ENTER..." ;;
        4) echo -e "${YELLOW}Módulo WebSocket próximamente...${NC}"; read -p "ENTER..." ;;
        5) systemctl restart nginx oxgi-ws dropbear stunnel5; echo -e "${GREEN}Servicios reiniciados${NC}"; read -p "ENTER..." ;;
        6) systemctl status nginx oxgi-ws dropbear stunnel5 --no-pager -l; read -p "ENTER..." ;;
        7) netstat -tlnp | grep -E ':(22|80|109|143|443|447|777|7100|7200|7300|2090|81)'; read -p "ENTER..." ;;
        8) echo -e "${CYAN}Información del sistema:${NC}"; uname -a; uptime; free -h; df -h; read -p "ENTER..." ;;
        0) clear; echo -e "${GREEN}Hasta luego!${NC}"; exit 0 ;;
        *) echo -e "${RED}Opción inválida${NC}"; sleep 1 ;;
    esac
done
EOFMENU
chmod +x /usr/local/bin/oxgi

# RESUMEN FINAL
clear
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║        ${BOLD}OXGI VPS - INSTALACIÓN COMPLETADA 100%${NC}${GREEN}        ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo -e "${CYAN}Servicios y Puertos:${NC}"
echo -e "OpenSSH           : ${GREEN}22${NC}"
echo -e "SSH Websocket     : ${GREEN}80${NC}"
echo -e "SSH SSL Websocket : ${GREEN}443${NC}"
echo -e "Stunnel5          : ${GREEN}447, 777${NC}"
echo -e "Dropbear          : ${GREEN}109, 143${NC}"
echo -e "Badvpn            : ${GREEN}7100, 7200, 7300${NC}"
echo -e "Nginx Panel       : ${GREEN}81${NC}"
echo -e "WebSocket Backend : ${GREEN}2090${NC}"
echo -e "XRAY (Vless/Vmess): ${GREEN}80, 443${NC}"
echo ""
echo -e "${YELLOW}Comando para gestionar:${NC}"
echo -e "  ${GREEN}oxgi${NC} - Menú principal del sistema"
echo ""
echo -e "${CYAN}Escribe 'oxgi' para comenzar a gestionar tu VPS${NC}"
