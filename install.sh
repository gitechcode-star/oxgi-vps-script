#!/bin/bash

# ═══════════════════════════════════════════════════════════════
# OXGI VPS SCRIPT - Instalador Automático
# ═══════════════════════════════════════════════════════════════

# Variables de configuración (se usarán para generar version.conf)
SCRIPT_NAME="OXGI VPS Script"
SCRIPT_VERSION="1.0.0"
DEVELOPER="gitechcode-star"
REPO_URL="https://github.com/gitechcode-star/oxgi-vps-script"
BRANCH="main"

INSTALL_DIR="/usr/local/oxgi"
BIN_LINK="/usr/local/bin/oxgi"
CONFIG_DIR="/etc/oxgi"

# Colores
GREEN='\033[1;32m'; RED='\033[1;31m'; YELLOW='\033[1;33m'; BLUE='\033[1;34m'; CYAN='\033[1;36m'; BOLD='\033[1m'; NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}════════════════════════════════════════${NC}"
        echo -e "${RED} ERROR: Este script debe ejecutarse como root.${NC}"
        echo -e "${RED} Usa: sudo bash <(curl -Ls ${REPO_URL}/raw/${BRANCH}/install.sh)${NC}"
        echo -e "${RED}════════════════════════════════════════${NC}"
        exit 1
    fi
}

check_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID; VER=$VERSION_ID
    else
        log_error "No se pudo detectar el sistema operativo."; exit 1
    fi
    if [[ "$OS" != "ubuntu" && "$OS" != "debian" ]]; then
        log_error "Este script solo es compatible con Ubuntu y Debian."; exit 1
    fi
    log_info "Sistema detectado: ${GREEN}$OS $VER${NC}"
}

step_verification() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                                                  ║${NC}"
    echo -e "${CYAN}║      ${GREEN}${BOLD}${SCRIPT_NAME} - INSTALADOR${NC}${CYAN}                      ║${NC}"
    echo -e "${CYAN}║                                                  ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    check_root
    check_os
    log_info "Verificando conexión a internet..."
    if ! ping -c 1 -W 3 google.com > /dev/null 2>&1; then
        log_error "No hay conexión a internet."; exit 1
    fi
    log_success "Conexión a internet OK"
    sleep 1
}

step_update_system() {
    echo -e "${BLUE}══════════════════════════════════════════════════${NC}"
    echo -e "  PASO 1/5: Actualizando sistema..."
    echo -e "${BLUE}══════════════════════════════════════════════════${NC}"
    export DEBIAN_FRONTEND=noninteractive
    apt update -y > /dev/null 2>&1
    apt upgrade -y > /dev/null 2>&1
    log_success "Sistema actualizado"
    sleep 1
}

step_install_dependencies() {
    echo -e "${BLUE}══════════════════════════════════════════════════${NC}"
    echo -e "  PASO 2/5: Instalando dependencias..."
    echo -e "${BLUE}══════════════════════════════════════════════════${NC}"
    DEPS=(git curl wget unzip sudo cron ufw nginx python3 python3-pip jq build-essential binutils cmake openssl libssl-dev net-tools dnsutils bc htop nano)
    log_info "Instalando paquetes esenciales..."
    apt install -y "${DEPS[@]}" > /dev/null 2>&1
    log_success "Dependencias instaladas"
    sleep 1
}

step_configure_firewall() {
    echo -e "${BLUE}══════════════════════════════════════════════════${NC}"
    echo -e "  PASO 3/5: Configurando Firewall (UFW)..."
    echo -e "${BLUE}══════════════════════════════════════════════════${NC}"
    ufw --force reset > /dev/null 2>&1
    ufw allow 22/tcp > /dev/null 2>&1
    ufw allow 80/tcp > /dev/null 2>&1
    ufw allow 443/tcp > /dev/null 2>&1
    ufw allow 444/tcp > /dev/null 2>&1
    ufw allow 7300/udp > /dev/null 2>&1
    ufw allow 8000:9000/tcp > /dev/null 2>&1
    echo "y" | ufw enable > /dev/null 2>&1
    log_success "Firewall configurado y activado"
    sleep 1
}

step_optimize_system() {
    echo -e "${BLUE}══════════════════════════════════════════════════${NC}"
    echo -e "  PASO 4/5: Optimizando sistema (TCP BBR)..."
    echo -e "${BLUE}══════════════════════════════════════════════════${NC}"
    if ! grep -q "bbr" /etc/sysctl.conf; then
        echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
        echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
        sysctl -p > /dev/null 2>&1
        log_success "TCP BBR activado"
    fi
    if ! grep -q "nofile" /etc/security/limits.conf; then
        echo "* soft nofile 1000000" >> /etc/security/limits.conf
        echo "* hard nofile 1000000" >> /etc/security/limits.conf
    fi
    sysctl -p > /dev/null 2>&1
    log_success "Optimizaciones de red aplicadas"
    sleep 1
}

step_install_script() {
    echo -e "${BLUE}══════════════════════════════════════════════════${NC}"
    echo -e "  PASO 5/5: Descargando ${SCRIPT_NAME}..."
    echo -e "${BLUE}══════════════════════════════════════════════════${NC}"
    
    mkdir -p $INSTALL_DIR
    mkdir -p $CONFIG_DIR
    
    if [[ -d "$INSTALL_DIR/.git" ]]; then
        cd $INSTALL_DIR && git pull origin $BRANCH > /dev/null 2>&1
    else
        git clone -b $BRANCH $REPO_URL $INSTALL_DIR > /dev/null 2>&1
    fi
    
    chmod +x $INSTALL_DIR/*.sh
    chmod +x $INSTALL_DIR/modules/*.sh 2>/dev/null
    ln -sf $INSTALL_DIR/oxgi.sh $BIN_LINK
    chmod +x $BIN_LINK
    
    # ═══════════════════════════════════════════════════════════════
    # CREAR ARCHIVO version.conf DINÁMICO
    # ═══════════════════════════════════════════════════════════════
    cat > $INSTALL_DIR/version.conf << EOF
# Configuración de ${SCRIPT_NAME}
SCRIPT_NAME="${SCRIPT_NAME}"
SCRIPT_VERSION="${SCRIPT_VERSION}"
DEVELOPER="${DEVELOPER}"
REPO_URL="${REPO_URL}"
BRANCH="${BRANCH}"
EOF
    
    log_success "Script instalado en $INSTALL_DIR"
    log_success "Comando 'oxgi' disponible globalmente"
    sleep 1
}

show_summary() {
    clear
    SERVER_IP=$(curl -s https://api.ipify.org 2>/dev/null || echo "127.0.0.1")
    
    echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                  ║${NC}"
    echo -e "${GREEN}║        ${CYAN}${BOLD}¡INSTALACIÓN COMPLETADA EXITOSAMENTE!${GREEN}       ║${NC}"
    echo -e "${GREEN}║                                                  ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}📊 INFORMACIÓN DEL SERVIDOR:${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "  • IP Pública     : ${GREEN}$SERVER_IP${NC}"
    echo -e "  • Sistema        : ${GREEN}$OS $VER${NC}"
    echo -e "  • Directorio     : ${GREEN}$INSTALL_DIR${NC}"
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}🔒 PUERTOS CONFIGURADOS:${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "  • 22/tcp: SSH  |  80/tcp: WS  |  443/tcp: SSL"
    echo -e "  • 444/tcp: Dropbear  |  7300/udp: BadVPN"
    echo ""
    echo -e "${GREEN}══════════════════════════════════════════════════${NC}"
    echo -e "  ${BOLD}Escribe el comando:${NC} ${CYAN}${BOLD}oxgi${NC}"
    echo -e "  ${BOLD}para abrir el panel de control.${NC}"
    echo -e "${GREEN}══════════════════════════════════════════════════${NC}"
    echo ""
}

main() {
    step_verification
    step_update_system
    step_install_dependencies
    step_configure_firewall
    step_optimize_system
    step_install_script
    show_summary
}

main
exit 0
