
#!/bin/bash

if [[ $EUID -ne 0 ]]; then
   echo -e "\e[31m[ERROR] Este script debe ejecutarse como root.\e[0m"
   exit 1
fi

GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

BADVPN_PORT="7300"

install_badvpn() {
    clear
    echo -e "${GREEN}══════════════════════════════════════${NC}"
    echo -e "      INSTALANDO BADVPN (UDPGW)"
    echo -e "${GREEN}══════════════════════════════════════${NC}"
    
    apt update -y > /dev/null 2>&1
    apt install -y build-essential binutils git > /dev/null 2>&1
    
    cd /tmp
    rm -rf badvpn
    mkdir badvpn
    cd badvpn
    
    echo -e "${YELLOW}[*] Descargando BadVPN...${NC}"
    git clone https://github.com/ambrop72/badvpn.git . > /dev/null 2>&1
    
    if [[ ! -f "CMakeLists.txt" ]]; then
        echo -e "${RED}[!] Error al descargar BadVPN.${NC}"
        read -p "Presiona ENTER..."
        return 1
    fi
    
    mkdir build
    cd build
    cmake .. -DBUILD_NOTHING_BY_DEFAULT=ON -DBUILD_UDPGW=ON > /dev/null 2>&1
    make > /dev/null 2>&1
    
    if [[ ! -f "udpgw/badvpn-udpgw" ]]; then
        echo -e "${RED}[!] Error al compilar BadVPN.${NC}"
        read -p "Presiona ENTER..."
        return 1
    fi
    
    cp udpgw/badvpn-udpgw /usr/bin/badvpn-udpgw
    chmod +x /usr/bin/badvpn-udpgw
    
    # Crear servicio systemd
    cat > /etc/systemd/system/badvpn.service << EOF
[Unit]
Description=BadVPN UDP Gateway
After=network.target

[Service]
Type=forking
ExecStart=/usr/bin/badvpn-udpgw --listen-addr 127.0.0.1:${BADVPN_PORT} --max-clients 1000 --max-connections-for-client 10
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable badvpn > /dev/null 2>&1
    systemctl start badvpn
    
    # Firewall
    if command -v ufw > /dev/null; then
        ufw allow ${BADVPN_PORT}/udp > /dev/null 2>&1
    fi
    
    clear
    echo -e "${GREEN}══════════════════════════════════════${NC}"
    echo -e "      ${GREEN}BADVPN INSTALADO EXITOSAMENTE${NC}"
    echo -e "${GREEN}══════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}📌 Configuración:${NC}"
    echo -e "  • Puerto UDP : ${GREEN}${BADVPN_PORT}${NC}"
    echo -e "  • Max Clientes: 1000"
    echo ""
    read -p "Presiona ENTER para continuar..."
}

restart_service() {
    systemctl restart badvpn
    echo -e "${GREEN}[OK] BadVPN reiniciado.${NC}"
    read -p "Presiona ENTER..."
}

status_service() {
    clear
    echo -e "${GREEN}══════════════════════════════════════${NC}"
    echo -e "        ESTADO DE BADVPN"
    echo -e "${GREEN}══════════════════════════════════════${NC}"
    echo ""
    systemctl is-active badvpn > /dev/null && echo -e "${GREEN}► Servicio: [ACTIVO]${NC}" || echo -e "${RED}► Servicio: [INACTIVO]${NC}"
    echo ""
    ss -uulpn | grep ${BADVPN_PORT} || echo -e "${RED}Puerto no en escucha${NC}"
    echo ""
    read -p "Presiona ENTER..."
}

uninstall_badvpn() {
    read -p "¿Desinstalar BadVPN? (s/n): " confirm
    if [[ "$confirm" == "s" || "$confirm" == "S" ]]; then
        systemctl stop badvpn > /dev/null 2>&1
        systemctl disable badvpn > /dev/null 2>&1
        rm -f /etc/systemd/system/badvpn.service
        rm -f /usr/bin/badvpn-udpgw
        rm -rf /tmp/badvpn
        systemctl daemon-reload
        echo -e "${GREEN}[OK] BadVPN desinstalado.${NC}"
    fi
    read -p "Presiona ENTER..."
}

while true; do
    clear
    echo "══════════════════════════════════════"
    echo -e "        ${GREEN}BADVPN MANAGER${NC}"
    echo "══════════════════════════════════════"
    echo ""
    echo -e "  [1] ${GREEN}Instalar BadVPN${NC}"
    echo -e "  [2] ${YELLOW}Reiniciar Servicio${NC}"
    echo -e "  [3] ${YELLOW}Ver Estado${NC}"
    echo -e "  [4] ${RED}Desinstalar${NC}"
    echo ""
    echo -e "  [0] ${NC}Regresar"
    echo "══════════════════════════════════════"
    echo ""
    read -p "Seleccione una opción [0-4]: " opt

    case $opt in
        1) install_badvpn ;;
        2) restart_service ;;
        3) status_service ;;
        4) uninstall_badvpn ;;
        0) break ;;
        *) echo -e "${RED}Opción inválida.${NC}"; sleep 1 ;;
    esac
done
