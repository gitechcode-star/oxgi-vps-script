#!/bin/bash
GREEN='\033[1;32m'; RED='\033[1;31m'; CYAN='\033[1;36m'; NC='\033[0m'

install_xray() {
    echo -e "${CYAN}Instalando Xray Core...${NC}"
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
    mkdir -p /etc/xray
    
    UUID=$(cat /proc/sys/kernel/random/uuid)
    IP=$(curl -s https://api.ipify.org)
    
    # Configuración Multi-Protocolo (VLESS, VMESS, TROJAN) en WS y gRPC
    cat > /etc/xray/config.json << EOF
{
  "log": {"loglevel": "warning"},
  "inbounds": [
    {
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [{"id": "${UUID}", "level": 0, "email": "vless@oxgi"}],
        "decryption": "none",
        "fallbacks": [
          {"dest": 2090, "xver": 1}
        ]
      },
      "streamSettings": {
        "network": "ws",
        "security": "tls",
        "tlsSettings": {
          "certificates": [{"certificateFile": "/etc/nginx/ssl/oxgi.crt", "keyFile": "/etc/nginx/ssl/oxgi.key"}]
        },
        "wsSettings": {"path": "/vless"}
      }
    },
    {
      "port": 80,
      "protocol": "vless",
      "settings": {
        "clients": [{"id": "${UUID}", "level": 0, "email": "vless-ntls@oxgi"}],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {"path": "/vless"}
      }
    },
    {
      "port": 443,
      "protocol": "vmess",
      "settings": {
        "clients": [{"id": "${UUID}", "level": 0, "email": "vmess@oxgi"}]
      },
      "streamSettings": {
        "network": "grpc",
        "security": "tls",
        "tlsSettings": {
          "certificates": [{"certificateFile": "/etc/nginx/ssl/oxgi.crt", "keyFile": "/etc/nginx/ssl/oxgi.key"}]
        },
        "grpcSettings": {"serviceName": "vmess-grpc"}
      }
    },
    {
      "port": 443,
      "protocol": "trojan",
      "settings": {
        "clients": [{"password": "${UUID}", "level": 0, "email": "trojan@oxgi"}]
      },
      "streamSettings": {
        "network": "ws",
        "security": "tls",
        "tlsSettings": {
          "certificates": [{"certificateFile": "/etc/nginx/ssl/oxgi.crt", "keyFile": "/etc/nginx/ssl/oxgi.key"}]
        },
        "wsSettings": {"path": "/trojan"}
      }
    }
  ],
  "outbounds": [{"protocol": "freedom", "tag": "direct"}]
}
EOF
    systemctl enable --now xray
    echo "$UUID" > /etc/oxgi/xray_uuid
    
    clear
    echo -e "${GREEN}✅ XRAY MULTI-PROTOCOL INSTALADO${NC}"
    echo -e "${CYAN}══════════════════════════════════════${NC}"
    echo -e "UUID/Password: ${GREEN}${UUID}${NC}"
    echo -e "Path WS: ${GREEN}/vless${NC} o ${GREEN}/trojan${NC}"
    echo -e "Service Name gRPC: ${GREEN}vmess-grpc${NC}"
    echo -e "Puertos: ${GREEN}80 (Non-TLS) / 443 (TLS)${NC}"
    echo -e "${CYAN}══════════════════════════════════════${NC}"
    read -p "ENTER para continuar..."
}

show_config() {
    UUID=$(cat /etc/oxgi/xray_uuid 2>/dev/null || echo "NO_INSTALADO")
    IP=$(curl -s https://api.ipify.org)
    clear
    echo -e "${CYAN}══════════════════════════════════════${NC}"
    echo -e "       CONFIGURACIONES XRAY${NC}"
    echo -e "${CYAN}══════════════════════════════════════${NC}"
    echo -e "${GREEN}VLESS TLS (443):${NC}"
    echo -e "vless://${UUID}@${IP}:443?encryption=none&security=tls&type=ws&path=/vless#OXGI-VLESS-TLS"
    echo ""
    echo -e "${GREEN}VLESS Non-TLS (80):${NC}"
    echo -e "vless://${UUID}@${IP}:80?encryption=none&security=none&type=ws&path=/vless#OXGI-VLESS-NTLS"
    echo ""
    echo -e "${GREEN}VMESS gRPC (443):${NC}"
    echo -e "vmess://${UUID}@${IP}:443?security=tls&type=grpc&serviceName=vmess-grpc#OXGI-VMESS-GRPC"
    echo ""
    echo -e "${GREEN}TROJAN WS (443):${NC}"
    echo -e "trojan://${UUID}@${IP}:443?security=tls&type=ws&path=/trojan#OXGI-TROJAN-WS"
    echo -e "${CYAN}══════════════════════════════════════${NC}"
    read -p "ENTER para continuar..."
}

while true; do
    clear
    echo -e "${CYAN}══════════════════════════════════════${NC}"
    echo -e "        ${GREEN}XRAY MANAGER${NC}"
    echo -e "${CYAN}══════════════════════════════════════${NC}"
    echo "1) Instalar / Reinstalar Xray"
    echo "2) Ver Configuraciones (URL)"
    echo "3) Reiniciar Servicio"
    echo "0) Salir"
    read -p "Opcion: " opt
    case $opt in
        1) install_xray ;;
        2) show_config ;;
        3) systemctl restart xray; echo "Reiniciado"; read -p "ENTER" ;;
        0) break ;;
    esac
done
