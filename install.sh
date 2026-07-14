```bash
#!/bin/bash

clear

APP_NAME="OXGI VPS"
VERSION="1.0.0"
AUTHOR="@CodeNex_oficial"

REPO_URL="https://github.com/gitechcode-star/oxgi-vps-script.git"
INSTALL_DIR="/usr/local/oxgi"

# Cargar colores desde modules/color.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "$SCRIPT_DIR/modules/color.sh" ]; then
    source "$SCRIPT_DIR/modules/color.sh"
else
    echo "No se encontró modules/color.sh"
    exit 1
fi

show_header() {
    clear
    echo -e "${CYAN}"
    echo "┌──────────────────────────────────────────────┐"
    printf "│ %-44s │\n" "$APP_NAME $VERSION"
    echo "└──────────────────────────────────────────────┘"
    echo -e "${NC}"
}

progress_bar() {
    local step="$1"
    local total="$2"
    local text="$3"

    echo
    echo -e "${CYAN}[${step}/${total}]${NC} ${WHITE}${text}${NC}"

    for ((i=0; i<=100; i+=2)); do
        filled=$((i/2))
        empty=$((50-filled))

        printf "\r${GREEN}["
        printf "%0.s█" $(seq 1 $filled)
        printf "%0.s░" $(seq 1 $empty)
        printf "] ${WHITE}%3d%%${NC}" "$i"

        sleep 0.02
    done

    echo
    echo -e "${GREEN}✓ Completado${NC}"
}

show_header

# ROOT
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[ERROR] Ejecuta como root${NC}"
    exit 1
fi

# UBUNTU
if ! grep -qi "ubuntu" /etc/os-release; then
    echo -e "${RED}[ERROR] Ubuntu requerido${NC}"
    exit 1
fi

# 1/7
progress_bar 1 7 "Actualizando sistema..."
apt update -y
apt upgrade -y

# 2/7
progress_bar 2 7 "Instalando dependencias..."
apt install -y \
git \
curl \
wget \
unzip \
sudo \
cron \
ufw \
nginx

# 3/7
progress_bar 3 7 "Descargando OXGI..."

rm -rf "$INSTALL_DIR"

git clone "$REPO_URL" "$INSTALL_DIR"

if [ ! -d "$INSTALL_DIR" ]; then
    echo -e "${RED}[ERROR] No se pudo descargar OXGI${NC}"
    exit 1
fi

# 4/7
progress_bar 4 7 "Configurando permisos..."

chmod +x "$INSTALL_DIR"/oxgi.sh
chmod +x "$INSTALL_DIR"/install.sh
chmod +x "$INSTALL_DIR"/modules/*.sh

# 5/7
progress_bar 5 7 "Creando configuración..."

mkdir -p /etc/oxgi

cat > /etc/oxgi/config.conf << 'EOF'
# SSH
SSH_PORT="22"
SSH_PORT_ALT="3303"

# HTTP
HTTP_PORT="80"
HTTPS_PORT="443"

# WebSocket
WS_PORT="700"

# Dropbear
DROPBEAR_PORT="444"

# BadVPN
BADVPN_PORT="7300"

# Xray
VLESS_PORT="8443"
VMESS_PORT="8080"
TROJAN_PORT="2083"
SS_PORT="8388"

# Features
ENABLE_VLESS="true"
ENABLE_VMESS="true"
ENABLE_TROJAN="true"
ENABLE_SS="false"

DOMAIN=""
EOF

cat > /etc/oxgi/version.conf << EOF
APP_NAME="$APP_NAME"
VERSION="$VERSION"
AUTHOR="$AUTHOR"
EOF

# 6/7
progress_bar 6 7 "Creando comando global..."

cat > /usr/local/bin/oxgi << EOF
#!/bin/bash
bash $INSTALL_DIR/oxgi.sh
EOF

chmod +x /usr/local/bin/oxgi

# 7/7
progress_bar 7 7 "Finalizando instalación..."

show_header

echo -e "${GREEN}"
echo "┌──────────────────────────────────────────────┐"
echo "│          INSTALACION COMPLETADA ✓            │"
echo "└──────────────────────────────────────────────┘"
echo -e "${NC}"

echo
echo -e "${CYAN}Comando:${NC} ${WHITE}oxgi${NC}"
echo -e "${CYAN}Versión:${NC} ${WHITE}$VERSION${NC}"
echo -e "${CYAN}Autor:${NC} ${WHITE}$AUTHOR${NC}"
echo
