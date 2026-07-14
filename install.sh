#!/bin/bash

clear

APP="OXGI VPS"
VERSION="1.0.0"

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
echo "===================================="
echo "       $APP $VERSION"
echo "===================================="
echo -e "${NC}"

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[ERROR] Ejecuta como root${NC}"
    exit 1
fi

echo -e "${GREEN}[1/8] Verificando sistema...${NC}"

if ! grep -q "Ubuntu" /etc/os-release; then
    echo -e "${RED}Ubuntu requerido${NC}"
    exit 1
fi

echo -e "${GREEN}[2/8] Actualizando paquetes...${NC}"

apt update -y
apt upgrade -y

echo -e "${GREEN}[3/8] Instalando dependencias...${NC}"

apt install -y \
curl \
wget \
git \
unzip \
ufw \
cron \
sudo \
nginx

echo -e "${GREEN}[4/8] Creando directorios...${NC}"

mkdir -p /etc/oxgi
mkdir -p /usr/local/oxgi
mkdir -p /usr/local/oxgi/modules
mkdir -p /usr/local/oxgi/services
mkdir -p /usr/local/oxgi/config

echo -e "${GREEN}[5/8] Copiando archivos...${NC}"

echo "[+] Descargando OXGI..."

rm -rf /usr/local/oxgi

git clone \
https://github.com/gitechcode-star/oxgi-vps-script.git \
/usr/local/oxgi

chmod +x /usr/local/oxgi/oxgi.sh
chmod +x /usr/local/oxgi/modules/*.sh

chmod +x /usr/local/oxgi/oxgi.sh
chmod +x /usr/local/oxgi/modules/*.sh 2>/dev/null

echo -e "${GREEN}[6/8] Creando comando global...${NC}"

cat > /usr/local/bin/oxgi << EOF
#!/bin/bash
bash /usr/local/oxgi/oxgi.sh
EOF

chmod +x /usr/local/bin/oxgi

echo -e "${GREEN}[7/8] Configuración inicial...${NC}"

if [ ! -f /etc/oxgi/config.conf ]; then

cat > /etc/oxgi/config.conf << EOF
APP_NAME="OXGI VPS"
VERSION="1.0.0"

SSH_PORT="22"
SSH_PORT_ALT="3303"

WS_PORT="700"

HTTP_PORT="80"
HTTPS_PORT="443"

DROPBEAR_PORT="444"

BADVPN_PORT="7300"
EOF

fi

echo -e "${GREEN}[8/8] Finalizando...${NC}"

echo
echo -e "${GREEN}INSTALACION COMPLETADA${NC}"
echo
echo "Comando:"
echo
echo "oxgi"
echo
