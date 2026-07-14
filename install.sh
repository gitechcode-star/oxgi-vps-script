#!/bin/bash

# ==================================
# OXGI VPS INSTALLER
# ==================================

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

echo -e "${CYAN}"
echo "======================================"
echo "      $APP_NAME $VERSION"
echo "======================================"
echo -e "${NC}"

# Root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[ERROR] Ejecuta como root${NC}"
    exit 1
fi

# Ubuntu
if ! grep -qi "ubuntu" /etc/os-release; then
    echo -e "${RED}[ERROR] Ubuntu requerido${NC}"
    exit 1
fi

echo -e "${GREEN}[1/8] Actualizando sistema...${NC}"
apt update -y
apt upgrade -y

echo -e "${GREEN}[2/8] Instalando dependencias...${NC}"
apt install -y \
git \
curl \
wget \
unzip \
sudo \
cron \
ufw \
nginx

echo -e "${GREEN}[3/8] Descargando OXGI...${NC}"

rm -rf "$INSTALL_DIR"

git clone "$REPO_URL" "$INSTALL_DIR"

if [ ! -d "$INSTALL_DIR" ]; then
    echo -e "${RED}[ERROR] No se pudo descargar OXGI${NC}"
    exit 1
fi

echo -e "${GREEN}[4/8] Configurando permisos...${NC}"

chmod +x "$INSTALL_DIR"/install.sh 2>/dev/null
chmod +x "$INSTALL_DIR"/oxgi.sh 2>/dev/null
chmod +x "$INSTALL_DIR"/modules/*.sh 2>/dev/null

echo -e "${GREEN}[5/8] Creando configuraciones...${NC}"

mkdir -p /etc/oxgi

# CONFIGURACION DEL VPS
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

# Dominio
DOMAIN=""
EOF

# VERSION DEL PANEL
cat > /etc/oxgi/version.conf << EOF
APP_NAME="$APP_NAME"
VERSION="$VERSION"
AUTHOR="$AUTHOR"
EOF

echo -e "${GREEN}[6/8] Creando Header Global...${NC}"

mkdir -p "$INSTALL_DIR/modules"

cat > "$INSTALL_DIR/modules/header.sh" << 'EOF'
#!/bin/bash

show_header() {

CONFIG="/etc/oxgi/config.conf"
VERSION_FILE="/etc/oxgi/version.conf"

[ -f "$CONFIG" ] && source "$CONFIG"
[ -f "$VERSION_FILE" ] && source "$VERSION_FILE"

clear

echo "══════════════════════════════════════════════════════════════"
echo "     $APP_NAME - Versión : $VERSION - ($AUTHOR)"
echo "══════════════════════════════════════════════════════════════"
echo

}
EOF

chmod +x "$INSTALL_DIR/modules/header.sh"

echo -e "${GREEN}[7/8] Creando comando global...${NC}"

cat > /usr/local/bin/oxgi << EOF
#!/bin/bash
bash $INSTALL_DIR/oxgi.sh
EOF

chmod +x /usr/local/bin/oxgi

echo -e "${GREEN}[8/8] Finalizando...${NC}"

clear

echo -e "${GREEN}"
echo "======================================"
echo "      INSTALACION COMPLETADA"
echo "======================================"
echo -e "${NC}"

echo
echo "Comando:"
echo
echo "oxgi"
echo
echo "Repositorio:"
echo "$REPO_URL"
echo

echo "Version:"
echo "$VERSION"
echo

echo "Autor:"
echo "$AUTHOR"
echo
