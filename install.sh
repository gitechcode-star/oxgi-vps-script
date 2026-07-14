#!/bin/bash

clear

APP_NAME="OXGI VPS"
VERSION="1.0.0"
AUTHOR="@CodeNex_oficial"

REPO_URL="https://github.com/gitechcode-star/oxgi-vps-script.git"
INSTALL_DIR="/usr/local/oxgi"

GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

loading() {
    local start=$1
    local end=$2
    local text="$3"

    for ((i=start; i<=end; i++)); do
        filled=$((i / 2))
        empty=$((50 - filled))

        printf "\r${CYAN}["
        printf "%0.s█" $(seq 1 $filled 2>/dev/null)
        printf "%0.s░" $(seq 1 $empty 2>/dev/null)
        printf "] ${GREEN}%3d%%${NC} ${text}" "$i"

        sleep 0.01
    done

    echo
}

echo -e "${CYAN}"
echo "======================================"
echo "      $APP_NAME $VERSION"
echo "======================================"
echo -e "${NC}"

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

loading 0 14 "Actualizando sistema..."
apt update -y
apt upgrade -y

loading 15 28 "Instalando dependencias..."
apt install -y \
git \
curl \
wget \
unzip \
sudo \
cron \
ufw \
nginx

loading 29 42 "Descargando OXGI..."

rm -rf "$INSTALL_DIR"

git clone "$REPO_URL" "$INSTALL_DIR"

if [ ! -d "$INSTALL_DIR" ]; then
    echo -e "${RED}[ERROR] No se pudo descargar OXGI${NC}"
    exit 1
fi

loading 43 56 "Configurando permisos..."

chmod +x "$INSTALL_DIR"/oxgi.sh
chmod +x "$INSTALL_DIR"/install.sh
chmod +x "$INSTALL_DIR"/modules/*.sh

loading 57 70 "Creando configuración..."

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

loading 71 85 "Creando comando global..."

cat > /usr/local/bin/oxgi << EOF
#!/bin/bash
bash $INSTALL_DIR/oxgi.sh
EOF

chmod +x /usr/local/bin/oxgi

loading 86 100 "Finalizando..."

clear

echo -e "${GREEN}"
echo "======================================"
echo "   INSTALACION COMPLETADA"
echo "======================================"
echo -e "${NC}"

echo
echo "Comando:"
echo "oxgi"
echo
echo "Versión:"
echo "$VERSION"
echo
echo "Autor:"
echo "$AUTHOR"
echo
