#!/bin/bash

if [[ $EUID -ne 0 ]]; then
   echo -e "\e[31m[ERROR] Este script debe ejecutarse como root.\e[0m"
   exit 1
fi

GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m'

UUID_FILE="/etc/oxgi/v2ray_uuid.db"
CONFIG_FILE="/etc/xray/config.json"

get_ip() {
    curl -s https://api.ipify.org || curl -s https://ifconfig.me
}

generate_uuid() {
    cat /proc/sys/kernel/random/uuid
}

install_xray() {
    clear
    echo -e "${GREEN}══════════════════════════════════════${NC}"
    echo -e "      INSTALANDO XRAY-CORE"
    echo -e "${GREEN}══════════════════════════════════════${NC}"
    
    mkdir -p /etc/xray
    mkdir -p /var/log/xray
    
    # Descargar e instalar Xray
    echo -e "${YELLOW}[*] Descargando Xray-core...${NC}"
    cd /tmp
    curl -L -o xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
    
    if [[ ! -f xray.zip ]]; then
        echo -e "${RED}[!] Error al descargar Xray.${NC}"
        read -p "Presiona ENTER..."
        return 1
    fi
    
    unzip -o xray.zip
    chmod +x xray
    mv xray /usr/local/bin/
    mv geoip.dat geosite.dat /usr/local/bin/
    
    # Crear configuración base
    UUID=$(generate_uuid)
    PORT=$((8000 + RANDOM % 1000))
    
    cat > $CONFIG_FILE << EOF
{
  "log": {
    "loglevel": "warning",
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log"
  },
  "inbounds": [
    {
      "port": ${PORT},
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${UUID}",
            "level": 0,
            "email": "user@oxgi.local"
          }
        ],
        "decryption": "none",
        "fallbacks": []
      },
      "streamSettings": {
        "network": "tcp"
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
EOF
    
    # Crear servicio systemd
    cat > /etc/systemd/system/xray.service << 'EOF'
[Unit]
Description=Xray Service
Documentation=https://github.com/xtls/xray-core
After=network.target nss-lookup.target

[Service]
User=nobody
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/bin/xray run -config /etc/xray/config.json
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOF
    
    # Guardar UUID
    mkdir -p /etc/oxgi
    echo "${UUID}|${PORT}|$(date +%s)" > $UUID_FILE
    
    systemctl daemon-reload
    systemctl enable xray > /dev/null 2>&1
    systemctl start xray
    
    if command -v ufw > /dev/null; then
        ufw allow ${PORT}/tcp > /dev/null 2>&1
    fi
    
    SERVER_IP=$(get_ip)
    
    clear
    echo -e "${GREEN}══════════════════════════════════════${NC}"
    echo -e "      ${GREEN}XRAY INSTALADO EXITOSAMENTE${NC}"
    echo -e "${GREEN}══════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}📌 CONFIGURACIÓN VLESS:${NC}"
    echo -e "  • IP        : ${SERVER_IP}"
    echo -e "  • Puerto    : ${GREEN}${PORT}${NC}"
    echo -e "  • UUID      : ${BLUE}${UUID}${NC}"
    echo -e "  • Protocolo : VLESS-TCP"
    echo ""
    echo -e "${YELLOW}🔗 URL de conexión:${NC}"
    echo -e "vless://${UUID}@${SERVER_IP}:${PORT}?encryption=none&type=tcp#OXGI-VPS"
    echo ""
    read -p "Presiona ENTER para continuar..."
}

add_user() {
    clear
    echo -e "${GREEN}══════════════════════════════════════${NC}"
    echo -e "        AGREGAR NUEVO USUARIO VLESS"
    echo -e "${GREEN}══════════════════════════════════════${NC}"
    echo ""
    
    if [[ ! -f $CONFIG_FILE ]]; then
        echo -e "${RED}[!] Xray no está instalado. Instala primero.${NC}"
        read -p "Presiona ENTER..."
        return 1
    fi
    
    read -p "Ingrese nombre del usuario: " USERNAME
    UUID=$(generate_uuid)
    
    # Leer configuración actual y agregar nuevo usuario
    python3 -c "
import json
with open('$CONFIG_FILE', 'r') as f:
    config = json.load(f)

new_client = {
    'id': '$UUID',
    'level': 0,
    'email': '$USERNAME@oxgi.local'
}

config['inbounds'][0]['settings']['clients'].append(new_client)

with open('$CONFIG_FILE', 'w') as f:
    json.dump(config, f, indent=2)
" 2>/dev/null || {
        echo -e "${RED}[!] Error al agregar usuario. Python3 no disponible.${NC}"
        read -p "Presiona ENTER..."
        return 1
    }
    
    # Guardar en base de datos
    echo "${USERNAME}|${UUID}|$(date +%s)" >> /etc/oxgi/v2ray_users.db
    
    systemctl restart xray
    
    SERVER_IP=$(get_ip)
    PORT=$(jq -r '.inbounds[0].port' $CONFIG_FILE)
    
    echo -e "${GREEN}[OK] Usuario agregado exitosamente.${NC}"
    echo ""
    echo -e "${YELLOW}🔗 URL:${NC}"
    echo -e "vless://${UUID}@${SERVER_IP}:${PORT}?encryption=none&type=tcp#OXGI-${USERNAME}"
    echo ""
    read -p "Presiona ENTER para continuar..."
}

list_users() {
    clear
    echo -e "${GREEN}══════════════════════════════════════${NC}"
    echo -e "        USUARIOS VLESS REGISTRADOS"
    echo -e "${GREEN}══════════════════════════════════════${NC}"
    echo ""
    
    if [[ -f /etc/oxgi/v2ray_users.db ]]; then
        echo -e "${YELLOW}Usuario | UUID | Fecha de creación${NC}"
        echo "────────────────────────────────────────"
        while IFS='|' read -r user uuid date; do
            echo -e "${GREEN}$user${NC} | ${uuid:0:8}... | $(date -d @$date '+%Y-%m-%d' 2>/dev/null || date -r $date '+%Y-%m-%d' 2>/dev/null || echo 'N/A')"
        done < /etc/oxgi/v2ray_users.db
    else
        echo -e "${RED}No hay usuarios registrados.${NC}"
    fi
    
    echo ""
    read -p "Presiona ENTER para continuar..."
}

restart_service() {
    systemctl restart xray
    echo -e "${GREEN}[OK] Xray reiniciado.${NC}"
    read -p "Presiona ENTER..."
}

status_service() {
    clear
    echo -e "${GREEN}══════════════════════════════════════${NC}"
    echo -e "        ESTADO DE XRAY"
    echo -e "${GREEN}══════════════════════════════════════${NC}"
    echo ""
    systemctl is-active xray > /dev/null && echo -e "${GREEN}► Servicio: [ACTIVO]${NC}" || echo -e "${RED}► Servicio: [INACTIVO]${NC}"
    echo ""
    echo -e "${YELLOW}► Puertos en escucha:${NC}"
    ss -tulpn | grep xray || echo "  Ninguno"
    echo ""
    read -p "Presiona ENTER..."
}

while true; do
    clear
    echo "══════════════════════════════════════"
    echo -e "        ${GREEN}V2RAY / XRAY MANAGER${NC}"
    echo "══════════════════════════════════════"
    echo ""
    echo -e "  [1] ${GREEN}Instalar Xray-Core${NC}"
    echo -e "  [2] ${BLUE}Agregar Usuario VLESS${NC}"
    echo -e "  [3] ${YELLOW}Ver Usuarios${NC}"
    echo -e "  [4] ${YELLOW}Reiniciar Servicio${NC}"
    echo -e "  [5] ${YELLOW}Ver Estado${NC}"
    echo -e "  [6] ${RED}Desinstalar Xray${NC}"
    echo ""
    echo -e "  [0] ${NC}Regresar"
    echo "══════════════════════════════════════"
    echo ""
    read -p "Seleccione una opción [0-6]: " opt

    case $opt in
        1) install_xray ;;
        2) add_user ;;
        3) list_users ;;
        4) restart_service ;;
        5) status_service ;;
        6)
            read -p "¿Desinstalar Xray? (s/n): " confirm
            if [[ "$confirm" == "s" || "$confirm" == "S" ]]; then
                systemctl stop xray > /dev/null 2>&1
                systemctl disable xray > /dev/null 2>&1
                rm -f /etc/systemd/system/xray.service
                rm -rf /etc/xray
                rm -f /usr/local/bin/xray
                rm -f /usr/local/bin/geoip.dat
                rm -f /usr/local/bin/geosite.dat
                systemctl daemon-reload
                echo -e "${GREEN}[OK] Xray desinstalado.${NC}"
            fi
            read -p "Presiona ENTER..."
            ;;
        0) break ;;
        *) echo -e "${RED}Opción inválida.${NC}"; sleep 1 ;;
    esac
done
