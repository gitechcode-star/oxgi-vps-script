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

run_step() {
    local percent="$1"
    local text="$2"
    shift 2

    "$@" >/dev/null 2>&1 &
    local pid=$!

    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0

    while kill -0 "$pid" 2>/dev/null; do
        printf "\r${CYAN}[%3d%%]${NC} ${GREEN}%s${NC} %s" \
        "$percent" \
        "${spin:$i:1}" \
        "$text"

        i=$(( (i + 1) % 10 ))
        sleep 0.1
    done

    wait "$pid"
    local status=$?

    if [ $status -eq 0 ]; then
        printf "\r${CYAN}[%3d%%]${NC} ${GREEN}✓${NC} %s\n" \
        "$percent" \
        "$text"
    else
        printf "\r${CYAN}[%3d%%]${NC} ${RED}✗${NC} %s\n" \
        "$percent" \
        "$text"
        exit 1
    fi
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

run_step 14 "Actualizando repositorios..." apt update -y

run_step 28 "Actualizando sistema..." apt upgrade -y

run_step 42 "Instalando dependencias..." apt install -y \
git \
curl \
wget \
unzip \
sudo \
cron \
ufw \
nginx

rm -rf "$INSTALL_DIR"

run_step 56 "Descargando OXGI..." git clone "$REPO_URL" "$INSTALL_DIR"

if [ ! -d "$INSTALL_DIR" ]; then
    echo -e "${RED}[ERROR] No se pudo descargar OXGI${NC}"
    exit 1
fi

run_step 70 "Configurando permisos..." chmod -R +x "$INSTALL_DIR"

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

cat > /usr/local/bin/oxgi << EOF
#!/bin/bash
bash $INSTALL_DIR/oxgi.sh
EOF

run_step 85 "Creando comando global..." chmod +x /usr/local/bin/oxgi

run_step 100 "Finalizando instalación..." sleep 2

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
