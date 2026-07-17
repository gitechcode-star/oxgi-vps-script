#!/bin/bash

# ══════════════════════════════════════════════════════════════
# OXGI VPS SCRIPT - Instalador Automático
# Versión: 1.0.0
# Compatible: Ubuntu 20.04/22.04/24.04, Debian 10/11/12
# ═══════════════════════════════════════════════════════════════

# Colores
GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
NC='\033[0m'

# Configuración
INSTALL_DIR="/usr/local/oxgi"
REPO_URL="https://github.com/gitechcode-star/oxgi-vps-script.git"
BRANCH="main"
BIN_LINK="/usr/local/bin/oxgi"
CONFIG_DIR="/etc/oxgi"

# ═══════════════════════════════════════════════════════════════
# FUNCIONES AUXILIARES
# ═══════════════════════════════════════════════════════════════

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Este script debe ejecutarse como root (sudo ./install.sh)"
        exit 1
    fi
}

check_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
    else
        log_error "No se pudo detectar el sistema operativo"
        exit 1
    fi
    
    if [[ "$OS" != "ubuntu" && "$OS" != "debian" ]]; then
        log_error "Este script solo es compatible con Ubuntu y Debian"
        exit 1
    fi
    
    log_info "Sistema detectado: $OS $VER"
}

get_ip() {
    curl -s https://api.ipify.org 2>/dev/null || curl -s https://ifconfig.me 2>/dev/null || echo "127.0.0.1"
}

# ═══════════════════════════════════════════════════════════════
# PASO 1: VERIFICACIONES INICIALES
# ═══════════════════════════════════════════════════════════════

step_verification() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                                                  ${NC}"
    echo -e "${CYAN}║      ${GREEN}OXGI VPS SCRIPT - INSTALADOR${NC}                ${CYAN}║${NC}"
    echo -e "${CYAN}║                                                  ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    
    check_root
    check_os
    
    log_info "Verificando conexión a internet..."
    if ! ping -c 1 -W 3 google.com > /dev/null 2>&1; then
        log_error "No hay conexión a internet. Verifica tu red."
        exit 1
    fi
    log_success "Conexión a internet OK"
    
    echo ""
    read -p "¿Deseas continuar con la instalación? (s/n): " confirm
    if [[ "$confirm" != "s" && "$confirm" != "S" ]]; then
        log_warn "Instalación cancelada"
        exit 0
    fi
}

# ══════════════════════════════════════════════════════════════
# PASO 2: ACTUALIZACIÓN DEL SISTEMA
# ═══════════════════════════════════════════════════════════════

step_update_system() {
    echo ""
    echo -e "${BLUE}══════════════════════════════════════════════════${NC}"
    echo -e "  PASO 1/7: Actualizando sistema..."
    echo -e "${BLUE}══════════════════════════════════════════════════${NC}"
    
    export DEBIAN_FRONTEND=noninteractive
    
    apt update -y > /dev/null 2>&1
    apt upgrade -y > /dev/null 2>&1
    
    log_success "Sistema actualizado"
}

# ═══════════════════════════════════════════════════════════════
# PASO 3: INSTALACIÓN DE DEPENDENCIAS
# ═══════════════════════════════════════════════════════════════

step_install_dependencies() {
    echo ""
    echo -e "${BLUE}══════════════════════════════════════════════════${NC}"
    echo -e "  PASO 2/7: Instalando dependencias..."
    echo -e "${BLUE}══════════════════════════════════════════════════${NC}"
    
    DEPS=(
        git curl wget unzip sudo cron ufw
        nginx python3 python3-pip jq
        build-essential binutils cmake
        openssl libssl-dev
        net-tools dnsutils
        bc htop nano
    )
    
    log_info "Instalando paquetes esenciales..."
    apt install -y "${DEPS[@]}" > /dev/null 2>&1
    
    if [[ $? -eq 0 ]]; then
        log_success "Dependencias instaladas correctamente"
    else
        log_warn "Algunos paquetes no pudieron instalarse (no crítico)"
    fi
}

# ═══════════════════════════════════════════════════════════════
# PASO 4: CONFIGURACIÓN DEL FIREWALL
# ═══════════════════════════════════════════════════════════════

step_configure_firewall() {
    echo ""
    echo -e "${BLUE}══════════════════════════════════════════════════${NC}"
    echo -e "  PASO 3/7: Configurando Firewall (UFW)..."
    echo -e "${BLUE}══════════════════════════════════════════════════${NC}"
    
    # Permitir SSH primero para no bloquear la conexión actual
    ufw allow 22/tcp > /dev/null 2>&1
    
    # Puertos esenciales
    ufw allow 80/tcp > /dev/null 2>&1    # HTTP / WebSocket
    ufw allow 443/tcp > /dev/null 2>&1   # HTTPS / SSL
    ufw allow 444/tcp > /dev/null 2>&1   # Dropbear
    ufw allow 7300/udp > /dev/null 2>&1  # BadVPN UDP
    
    # Rango de puertos para V2Ray/Xray (8000-9000)
    ufw allow 8000:9000/tcp > /dev/null 2>&1
    
    # Activar UFW
    echo "y" | ufw enable > /dev/null 2>&1
    
    log_success "Firewall configurado y activado"
    log_info "Puertos abiertos: 22, 80, 443, 444, 7300(UDP), 8000-9000"
}

# ═══════════════════════════════════════════════════════════════
# PASO 5: OPTIMIZACIÓN DEL SISTEMA
# ═══════════════════════════════════════════════════════════════

step_optimize_system() {
    echo ""
    echo -e "${BLUE}══════════════════════════════════════════════════${NC}"
    echo -e "  PASO 4/7: Optimizando sistema..."
    echo -e "${BLUE}══════════════════════════════════════════════════${NC}"
    
    # Activar TCP BBR para mejor rendimiento de red
    log_info "Activando TCP BBR..."
    if ! grep -q "bbr" /etc/sysctl.conf; then
        echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
        echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
        sysctl -p > /dev/null 2>&1
        log_success "TCP BBR activado"
    else
        log_info "TCP BBR ya estaba activado"
    fi
    
    # Aumentar límites de archivos abiertos
    if ! grep -q "nofile" /etc/security/limits.conf; then
        echo "* soft nofile 1000000" >> /etc/security/limits.conf
        echo "* hard nofile 1000000" >> /etc/security/limits.conf
        log_success "Límites de archivos aumentados"
    fi
    
    # Optimizaciones de red adicionales
    cat >> /etc/sysctl.conf << 'EOF'

# OXGI VPS Optimizations
net.ipv4.tcp_max_syn_backlog=65536
net.core.somaxconn=65536
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_fin_timeout=15
net.ipv4.tcp_keepalive_time=300
net.ipv4.ip_local_port_range=1024 65535
EOF
    
    sysctl -p > /dev/null 2>&1
    log_success "Optimizaciones de red aplicadas"
}

# ═══════════════════════════════════════════════════════════════
# PASO 6: DESCARGA E INSTALACIÓN DEL SCRIPT
# ═══════════════════════════════════════════════════════════════

step_install_script() {
    echo ""
    echo -e "${BLUE}══════════════════════════════════════════════════${NC}"
    echo -e "  PASO 5/7: Descargando OXGI VPS Script..."
    echo -e "${BLUE}══════════════════════════════════════════════════${NC}"
    
    # Crear directorios necesarios
    mkdir -p $INSTALL_DIR
    mkdir -p $CONFIG_DIR
    
    # Clonar o actualizar el repositorio
    if [[ -d "$INSTALL_DIR/.git" ]]; then
        log_info "Actualizando instalación existente..."
        cd $INSTALL_DIR
        git pull origin $BRANCH > /dev/null 2>&1
    else
        log_info "Clonando repositorio..."
        git clone -b $BRANCH $REPO_URL $INSTALL_DIR > /dev/null 2>&1
    fi
    
    if [[ $? -ne 0 ]]; then
        log_error "Error al descargar el script"
        exit 1
    fi
    
    # Dar permisos de ejecución a todos los scripts
    chmod +x $INSTALL_DIR/*.sh
    chmod +x $INSTALL_DIR/modules/*.sh 2>/dev/null
    
    # Crear enlace simbólico para ejecutar desde cualquier lugar
    ln -sf $INSTALL_DIR/oxgi.sh $BIN_LINK
    chmod +x $BIN_LINK
    
    log_success "Script instalado en $INSTALL_DIR"
    log_success "Comando 'oxgi' disponible globalmente"
}

# ═══════════════════════════════════════════════════════════════
# PASO 7: CONFIGURACIÓN DE SERVICIOS Y CRON
# ═══════════════════════════════════════════════════════════════

step_configure_services() {
    echo ""
    echo -e "${BLUE}══════════════════════════════════════════════════${NC}"
    echo -e "  PASO 6/7: Configurando servicios..."
    echo -e "${BLUE}══════════════════════════════════════════════════${NC}"
    
    # Crear script de limpieza automática de usuarios expirados
    cat > $CONFIG_DIR/clean_expired.sh << 'CLEANEOF'
#!/bin/bash
# Limpieza automática de usuarios SSH expirados
DB_FILE="/etc/oxgi/ssh_users.db"

if [[ -f $DB_FILE ]]; then
    while IFS='|' read -r user pass expiry date; do
        if [[ -n "$expiry" ]]; then
            exp_timestamp=$(date -d "$expiry" +%s 2>/dev/null)
            if [[ $? -eq 0 && $exp_timestamp -lt $(date +%s) ]]; then
                userdel -r "$user" 2>/dev/null
                sed -i "/^${user}|/d" $DB_FILE
            fi
        fi
    done < $DB_FILE
fi
CLEANEOF
    
    chmod +x $CONFIG_DIR/clean_expired.sh
    
    # Agregar tarea cron para limpieza diaria a las 3 AM
    if ! crontab -l 2>/dev/null | grep -q "clean_expired.sh"; then
        (crontab -l 2>/dev/null; echo "0 3 * * * /etc/oxgi/clean_expired.sh > /dev/null 2>&1") | crontab -
        log_success "Cron job creado para limpieza automática"
    fi
    
    # Crear archivo de versión
    cat > $INSTALL_DIR/version.conf << 'EOF'
OXGI_VPS_SCRIPT_VERSION=1.0.0
INSTALL_DATE=$(date +%Y-%m-%d)
EOF
    
    log_success "Servicios configurados"
}

# ═══════════════════════════════════════════════════════════════
# PASO 8: VERIFICACIÓN FINAL
# ═══════════════════════════════════════════════════════════════

step_final_verification() {
    echo ""
    echo -e "${BLUE}══════════════════════════════════════════════════${NC}"
    echo -e "  PASO 7/7: Verificación final..."
    echo -e "${BLUE}══════════════════════════════════════════════════${NC}"
    
    # Verificar que el comando oxgi esté disponible
    if command -v oxgi > /dev/null 2>&1; then
        log_success "Comando 'oxgi' verificado"
    else
        log_error "El comando 'oxgi' no está disponible"
    fi
    
    # Verificar firewall
    if ufw status | grep -q "active"; then
        log_success "Firewall activo"
    else
        log_warn "Firewall no está activo"
    fi
    
    # Verificar BBR
    if sysctl net.ipv4.tcp_congestion_control | grep -q "bbr"; then
        log_success "TCP BBR activo"
    else
        log_warn "TCP BBR no está activo"
    fi
}

# ══════════════════════════════════════════════════════════════
# RESUMEN FINAL
# ═══════════════════════════════════════════════════════════════

show_summary() {
    clear
    SERVER_IP=$(get_ip)
    
    echo -e "${GREEN}══════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                  ║${NC}"
    echo -e "${GREEN}║        ${CYAN}¡INSTALACIÓN COMPLETADA EXITOSAMENTE!${GREEN}        ║${NC}"
    echo -e "${GREEN}║                                                  ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}📊 INFORMACIÓN DEL SERVIDOR:${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "  • IP Pública     : ${GREEN}$SERVER_IP${NC}"
    echo -e "  • Sistema        : ${GREEN}$OS $VER${NC}"
    echo -e "  • Directorio     : ${GREEN}$INSTALL_DIR${NC}"
    echo -e "  • Configuración  : ${GREEN}$CONFIG_DIR${NC}"
    echo ""
    
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}🚀 CÓMO USAR:${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "  • Ejecutar menú  : ${GREEN}oxgi${NC}"
    echo -e "  • Actualizar     : ${GREEN}cd $INSTALL_DIR && git pull${NC}"
    echo -e "  • Ver logs       : ${GREEN}tail -f /var/log/oxgi.log${NC}"
    echo ""
    
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}🔒 PUERTOS CONFIGURADOS:${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "  • 22/tcp   - SSH"
    echo -e "  • 80/tcp   - HTTP / WebSocket"
    echo -e "  • 443/tcp  - HTTPS / SSL"
    echo -e "  • 444/tcp  - Dropbear"
    echo -e "  • 7300/udp - BadVPN UDP"
    echo -e "  • 8000-9000/tcp - V2Ray/Xray"
    echo ""
    
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}⚙️  SERVICIOS INSTALADOS:${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "  ✓ Nginx (Proxy inverso)"
    echo -e "  ✓ UFW (Firewall)"
    echo -e "  ✓ TCP BBR (Optimización)"
    echo -e "  ✓ Cron (Limpieza automática)"
    echo ""
    
    echo -e "${GREEN}══════════════════════════════════════════════════${NC}"
    echo -e "  ${BOLD}Escribe 'oxgi' para comenzar${NC}"
    echo -e "${GREEN}══════════════════════════════════════════════════${NC}"
    echo ""
}

# ═══════════════════════════════════════════════════════════════
# EJECUCIÓN PRINCIPAL
# ═══════════════════════════════════════════════════════════════

main() {
    step_verification
    step_update_system
    step_install_dependencies
    step_configure_firewall
    step_optimize_system
    step_install_script
    step_configure_services
    step_final_verification
    show_summary
}

# Ejecutar instalación
main

exit 0
