#!/bin/bash

clear

APP_NAME="OXGI VPS"
VERSION="1.0.0"
AUTHOR="@CodeNex_oficial"

REPO_URL="https://github.com/gitechcode-star/oxgi-vps-script.git"
INSTALL_DIR="/usr/local/oxgi"

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

run_step() {
    local text="$1"
    shift

    echo
    echo -e "${WHITE}${text}${NC}"

    "$@" >/tmp/oxgi_install.log 2>&1 &
    local pid=$!

    local progress=0

    while kill -0 "$pid" 2>/dev/null; do

        if [ $progress -lt 95 ]; then
            progress=$((progress + 1))
        fi

        filled=$((progress * 30 / 100))
        empty=$((30 - filled))

        bar=""

        for ((i=0; i<filled; i++)); do
            bar="${bar}█"
        done

        for ((i=0; i<empty; i++)); do
            bar="${bar}░"
        done

        printf "\r${CYAN}[%s] ${GREEN}%3d%%${NC}" "$bar" "$progress"

        sleep 0.10
    done

    wait "$pid"
    local status=$?

    if [ $status -eq 0 ]; then
        printf "\r${CYAN}[██████████████████████████████] ${GREEN}100%% ✓${NC}\n"
    else
        echo
        echo -e "${RED}[ERROR] ${text}${NC}"
        cat /tmp/oxgi_install.log
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

apt update -y >/dev/null 2>&1
apt install -y whiptail dialog >/dev/null 2>&1

whiptail \
--title "OXGI VPS" \
--yesno "¿Deseas iniciar la instalación de OXGI VPS?" 10 60

if [ $? -ne 0 ]; then
    clear
    echo "Instalación cancelada."
    exit 0
fi

run_step "Actualizando repositorios..." \
apt update -y

run_step "Actualizando sistema..." \
apt upgrade -y \
-o Dpkg::Options::="--force-confdef" \
-o Dpkg::Options::="--force-confold"

run_step "Instalando dependencias..." \
apt install -y \
-o Dpkg::Options::="--force-confdef" \
-o Dpkg::Options::="--force-confold" \
git \
curl \
wget \
unzip \
sudo \
cron \
ufw \
nginx \
dialog \
whiptail

rm -rf "$INSTALL_DIR"

run_step "Descargando OXGI..." \
git clone "$REPO_URL" "$INSTALL_DIR"

if [ ! -d "$INSTALL_DIR" ]; then
    echo -e "${RED}[ERROR] No se pudo descargar OXGI${NC}"
    exit 1
fi

run_step "Configurando permisos..." \
chmod -R +x "$INSTALL_DIR"

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

run_step "Creando comando global..." \
chmod +x /usr/local/bin/oxgi

run_step "Finalizando instalación..." \
sleep 2

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
