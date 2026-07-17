#!/bin/bash

# ═══════════════════════════════════════════════════════════════
# OXGI VPS SCRIPT - Instalador Automático Completo
# Incluye: SSH, WebSocket, SSL/443, V2Ray, BadVPN, Dropbear
# Repositorio: https://github.com/gitechcode-star/oxgi-vps-script
# ═══════════════════════════════════════════════════════════════

# Variables de Configuración
SCRIPT_NAME="OXGI VPS Script"
SCRIPT_VERSION="1.0.0"
DEVELOPER="gitechcode-star"
REPO_URL="https://github.com/gitechcode-star/oxgi-vps-script"
BRANCH="main"

INSTALL_DIR="/usr/local/oxgi"
BIN_LINK="/usr/local/bin/oxgi"
CONFIG_DIR="/etc/oxgi"
TOTAL_STEPS=10

# Colores
GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
BOLD='\033[1m'
NC='\033[0m'

# ═══════════════════════════════════════════════════════════════
# FUNCIONES AUXILIARES
# ═══════════════════════════════════════════════════════════════

draw_progress() {
    local current=$1
    local total=$2
    local msg=$3
    local percent=$(( (current * 100) / total ))
    local bar_width=40
    local filled=$(( (percent * bar_width) / 100 ))
    local empty=$(( bar_width - filled ))
    
    local bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done
    
    printf "\r\033[K  ${CYAN}[${bar}]${NC} %3d%% | ${YELLOW}%s${NC}" "$percent" "$msg"
}

clear_progress_line() { printf "\r\033[K"; }
log_error() { echo -e "\n${RED}[ERROR]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}══════════════════════════════════════════════════${NC}"
        echo -e "${RED} ERROR: Este script debe ejecutarse como root.${NC}"
        echo -e "${RED} Usa: sudo bash <(curl -Ls ${REPO_URL}/raw/${BRANCH}/install.sh)${NC}"
        echo -e "${RED}══════════════════════════════════════════════════${NC}"
        exit 1
    fi
}

check_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
    else
        log_error "No se pudo detectar el sistema operativo."
        exit 1
    fi
    if [[ "$OS" != "ubuntu" && "$OS" != "debian" ]]; then
        log_error "Este script solo es compatible con Ubuntu y Debian."
        exit 1
    fi
}

get_ip() {
    curl -s https://api.ipify.org 2>/dev/null || curl -s https://ifconfig.me 2>/dev/null || echo "127.0.0.1"
}

# ═══════════════════════════════════════════════════════════════
# PASOS DE INSTALACIÓN
# ═══════════════════════════════════════════════════════════════

step_1_verification() {
    draw_progress 1 $TOTAL_STEPS "Verificando sistema y conexión a internet..."
    check_root
    check_os
    if ! ping -c 1 -W 3 google.com > /dev/null 2>&1; then
        clear_progress_line
        log_error "No hay conexión a internet. Verifica tu red."
        exit 1
    fi
    sleep 1
}

step_2_update() {
    draw_progress 2 $TOTAL_STEPS "Actualizando paquetes del sistema (esto puede tardar)..."
    export DEBIAN_FRONTEND=noninteractive
    apt update -y > /dev/null 2>&1
    apt upgrade -y > /dev/null 2>&1
    sleep 1
}

step_3_dependencies() {
    draw_progress 3 $TOTAL_STEPS "Instalando dependencias esenciales..."
    DEPS=(git curl wget unzip sudo cron ufw nginx python3 python3-pip jq \
          build-essential binutils cmake openssl libssl-dev net-tools \
          dnsutils bc htop nano websockify dropbear certbot python3-certbot-nginx)
    apt install -y "${DEPS[@]}" > /dev/null 2>&1
    sleep 1
}

step_4_firewall() {
    draw_progress 4 $TOTAL_STEPS "Configurando Firewall (UFW) y abriendo puertos..."
    ufw --force reset > /dev/null 2>&1
    ufw allow 22/tcp > /dev/null 2>&1
    ufw allow 80/tcp > /dev/null 2>&1
    ufw allow 443/tcp > /dev/null 2>&1
    ufw allow 444/tcp > /dev/null 2>&1
    ufw allow 7300/udp > /dev/null 2>&1
    ufw allow 8443/tcp > /dev/null 2>&1
    echo "y" | ufw enable > /dev/null 2>&1
    sleep 1
}

step_5_optimization() {
    draw_progress 5 $TOTAL_STEPS "Optimizando red del sistema (Activando TCP BBR)..."
    if ! grep -q "bbr" /etc/sysctl.conf; then
        echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
        echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
        sysctl -p > /dev/null 2>&1
    fi
    if ! grep -q "nofile" /etc/security/limits.conf; then
        echo "* soft nofile 1000000" >> /etc/security/limits.conf
        echo "* hard nofile 1000000" >> /etc/security/limits.conf
    fi
    cat >> /etc/sysctl.conf << 'EOF'
net.ipv4.tcp_max_syn_backlog=65536
net.core.somaxconn=65536
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_fin_timeout=15
EOF
    sysctl -p > /dev/null 2>&1
    sleep 1
}

step_6_ssl_nginx() {
    draw_progress 6 $TOTAL_STEPS "Configurando Nginx con SSL/TLS (Puertos 80 y 443)..."
    
    # Crear certificado SSL autofirmado (se puede reemplazar con Let's Encrypt después)
    mkdir -p /etc/nginx/ssl
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/nginx/ssl/oxgi.key \
        -out /etc/nginx/ssl/oxgi.crt \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=oxgi.local" > /dev/null 2>&1
    
    # Configuración de Nginx con HTTP y HTTPS
    rm -f /etc/nginx/sites-enabled/default
    cat > /etc/nginx/sites-available/oxgi-ssl << 'EOF'
# HTTP - Redirección y WebSocket
server {
    listen 80;
    server_name _;

    # WebSocket para SSH
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }
}

# HTTPS - SSL/TLS
server {
    listen 443 ssl http2;
    server_name _;

    ssl_certificate /etc/nginx/ssl/oxgi.crt;
    ssl_certificate_key /etc/nginx/ssl/oxgi.key;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # WebSocket para SSH sobre TLS
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }
}
EOF
    
    ln -sf /etc/nginx/sites-available/oxgi-ssl /etc/nginx/sites-enabled/
    
    # Configurar Websockify
    cat > /etc/systemd/system/websockify.service << 'EOF'
[Unit]
Description=Websockify SSH Bridge
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/websockify 8080 127.0.0.1:22
Restart=on-failure
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable websockify > /dev/null 2>&1
    systemctl enable nginx > /dev/null 2>&1
    systemctl restart websockify
    systemctl restart nginx
    sleep 1
}

step_7_websocket() {
    draw_progress 7 $TOTAL_STEPS "Configurando SSH WebSocket..."
    # Ya configurado en el paso anterior con SSL
    sleep 1
}

step_8_v2ray() {
    draw_progress 8 $TOTAL_STEPS "Instalando y configurando V2Ray/Xray Core (VLESS)..."
    
    mkdir -p /etc/xray /var/log/xray
    cd /tmp
    curl -L -o xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip > /dev/null 2>&1
    
    if [[ -f xray.zip ]]; then
        unzip -o xray.zip > /dev/null 2>&1
        chmod +x xray
        mv xray /usr/local/bin/
        mv geoip.dat geosite.dat /usr/local/bin/ 2>/dev/null
        
        UUID=$(cat /proc/sys/kernel/random/uuid)
        PORT=8443
        
        cat > /etc/xray/config.json << EOF
{
  "log": { "loglevel": "warning", "access": "/var/log/xray/access.log", "error": "/var/log/xray/error.log" },
  "inbounds": [{
    "port": ${PORT},
    "protocol": "vless",
    "settings": {
      "clients": [{ "id": "${UUID}", "level": 0, "email": "admin@oxgi.local" }],
      "decryption": "none"
    },
    "streamSettings": { "network": "tcp" }
  }],
  "outbounds": [{ "protocol": "freedom", "settings": {} }]
}
EOF
        
        cat > /etc/systemd/system/xray.service << 'EOF'
[Unit]
Description=Xray Service
After=network.target nss-lookup.target

[Service]
User=nobody
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/bin/xray run -config /etc/xray/config.json
Restart=on-failure
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOF
        
        mkdir -p /etc/oxgi
        echo "admin|${UUID}|$(date +%s)" > /etc/oxgi/v2ray_users.db
        
        systemctl daemon-reload
        systemctl enable xray > /dev/null 2>&1
        systemctl start xray
    fi
    sleep 1
}

step_9_badvpn_dropbear() {
    draw_progress 9 $TOTAL_STEPS "Compilando BadVPN y configurando Dropbear..."
    
    # BadVPN
    cd /tmp
    rm -rf badvpn
    mkdir badvpn && cd badvpn
    git clone https://github.com/ambrop72/badvpn.git . > /dev/null 2>&1
    if [[ -f "CMakeLists.txt" ]]; then
        mkdir build && cd build
        cmake .. -DBUILD_NOTHING_BY_DEFAULT=ON -DBUILD_UDPGW=ON > /dev/null 2>&1
        make > /dev/null 2>&1
        if [[ -f "udpgw/badvpn-udpgw" ]]; then
            cp udpgw/badvpn-udpgw /usr/bin/badvpn-udpgw
            chmod +x /usr/bin/badvpn-udpgw
            
            cat > /etc/systemd/system/badvpn.service << 'EOF'
[Unit]
Description=BadVPN UDP Gateway
After=network.target

[Service]
Type=forking
ExecStart=/usr/bin/badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 1000 --max-connections-for-client 10
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
            systemctl daemon-reload
            systemctl enable badvpn > /dev/null 2>&1
            systemctl start badvpn
        fi
    fi
    
    # Dropbear
    cat > /etc/default/dropbear << EOF
NO_START=0
DROPBEAR_PORT=444
DROPBEAR_EXTRA_ARGS="-w -s -j -k"
DROPBEAR_RSAKEY="/etc/dropbear/dropbear_rsa_host_key"
DROPBEAR_DSSKEY="/etc/dropbear/dropbear_dss_host_key"
EOF
    systemctl enable dropbear > /dev/null 2>&1
    systemctl restart dropbear
    sleep 1
}

step_10_install_script_and_cron() {
    draw_progress 10 $TOTAL_STEPS "Descargando panel de control y configurando cron..."
    
    mkdir -p $INSTALL_DIR $CONFIG_DIR
    
    if [[ -d "$INSTALL_DIR/.git" ]]; then
        cd $INSTALL_DIR && git pull origin $BRANCH > /dev/null 2>&1
    else
        git clone -b $BRANCH $REPO_URL $INSTALL_DIR > /dev/null 2>&1
    fi
    
    chmod +x $INSTALL_DIR/*.sh $INSTALL_DIR/modules/*.sh 2>/dev/null
    ln -sf $INSTALL_DIR/oxgi.sh $BIN_LINK
    chmod +x $BIN_LINK
    
    # Crear version.conf
    cat > $INSTALL_DIR/version.conf << EOF
SCRIPT_NAME="${SCRIPT_NAME}"
SCRIPT_VERSION="${SCRIPT_VERSION}"
DEVELOPER="${DEVELOPER}"
REPO_URL="${REPO_URL}"
BRANCH="${BRANCH}"
EOF

    # Crear script de auto-limpieza (2 días después de expirar)
    cat > $CONFIG_DIR/auto_clean.sh << 'CLEANEOF'
#!/bin/bash
DB_FILE="/etc/oxgi/ssh_users.db"
[[ ! -f "$DB_FILE" ]] && exit 0

current_ts=$(date +%s)
temp_file="${DB_FILE}.tmp"
> "$temp_file"

while IFS='|' read -r user pass devices created expiry auto_delete_ts; do
    if [[ -n "$user" ]]; then
        if [[ "$current_ts" -gt "$auto_delete_ts" ]]; then
            userdel -r "$user" 2>/dev/null
        else
            echo "${user}|${pass}|${devices}|${created}|${expiry}|${auto_delete_ts}" >> "$temp_file"
        fi
    fi
done < "$DB_FILE"
mv "$temp_file" "$DB_FILE"
CLEANEOF
    chmod +x $CONFIG_DIR/auto_clean.sh
    
    # Agregar al cron (ejecutar cada hora)
    if ! crontab -l 2>/dev/null | grep -q "auto_clean.sh"; then
        (crontab -l 2>/dev/null; echo "0 * * * * /bin/bash /etc/oxgi/auto_clean.sh > /dev/null 2>&1") | crontab -
    fi
    sleep 1
}

# ═══════════════════════════════════════════════════════════════
# RESUMEN FINAL
# ═══════════════════════════════════════════════════════════════

show_summary() {
    clear
    clear_progress_line
    SERVER_IP=$(get_ip)
    V2RAY_UUID=""
    
    if [[ -f /etc/oxgi/v2ray_users.db ]]; then
        V2RAY_UUID=$(cut -d'|' -f2 /etc/oxgi/v2ray_users.db | head -1)
    fi
    
    echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                  ║${NC}"
    echo -e "${GREEN}║        ${CYAN}${BOLD}¡INSTALACIÓN COMPLETADA EXITOSAMENTE!${GREEN}       ║${NC}"
    echo -e "${GREEN}║                                                  ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}📊 SERVIDOR:${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "  • IP Pública : ${GREEN}$SERVER_IP${NC}"
    echo -e "  • Sistema    : ${GREEN}$OS $VER${NC}"
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}✅ SERVICIOS CONFIGURADOS Y ACTIVOS:${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "  ✓ SSH Estándar        : Puerto 22"
    echo -e "  ✓ SSH WebSocket (HTTP): Puerto 80"
    echo -e "  ✓ SSH WebSocket (HTTPS): Puerto 443 ${GREEN}(SSL/TLS)${NC}"
    echo -e "  ✓ Dropbear            : Puerto 444"
    echo -e "  ✓ V2Ray/Xray VLESS    : Puerto 8443"
    echo -e "  ✓ BadVPN UDP          : Puerto 7300"
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}🔗 URL V2Ray/VLESS:${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    if [[ -n "$V2RAY_UUID" ]]; then
        echo -e "${GREEN}vless://${V2RAY_UUID}@${SERVER_IP}:8443?encryption=none&type=tcp#OXGI-VPS${NC}"
    fi
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}⚙️  CONFIGURACIÓN WEBSOCKET:${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "  • HTTP (Puerto 80):"
    echo -e "      Host: ${SERVER_IP} | Path: / | Type: WebSocket"
    echo -e "  • HTTPS (Puerto 443):"
    echo -e "      Host: ${SERVER_IP} | Path: / | Type: WebSocket + TLS"
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW} NOTA SOBRE SSL:${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "  • Certificado autofirmado instalado"
    echo -e "  • Para usar Let's Encrypt:"
    echo -e "    ${GREEN}certbot --nginx -d tudominio.com${NC}"
    echo ""
    echo -e "${GREEN}══════════════════════════════════════════════════${NC}"
    echo -e "  ${BOLD}Escribe el comando:${NC} ${CYAN}${BOLD}oxgi${NC}"
    echo -e "  ${BOLD}para abrir el panel de control.${NC}"
    echo -e "${GREEN}══════════════════════════════════════════════════${NC}"
    echo ""
}

# ═══════════════════════════════════════════════════════════════
# EJECUCIÓN PRINCIPAL
# ═══════════════════════════════════════════════════════════════

main() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                                                  ║${NC}"
    echo -e "${CYAN}║      ${GREEN}${BOLD}${SCRIPT_NAME}${NC}${CYAN}                           ║${NC}"
    echo -e "${CYAN}║      ${YELLOW}Versión: ${SCRIPT_VERSION}${NC}${CYAN}                      ║${NC}"
    echo -e "${CYAN}║                                                  ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    
    step_1_verification
    step_2_update
    step_3_dependencies
    step_4_firewall
    step_5_optimization
    step_6_ssl_nginx
    step_7_websocket
    step_8_v2ray
    step_9_badvpn_dropbear
    step_10_install_script_and_cron
    
    clear_progress_line
    echo -e "\n${GREEN}[OK]${NC} Todos los pasos completados.\n"
    sleep 1
    show_summary
}

main
exit 0
