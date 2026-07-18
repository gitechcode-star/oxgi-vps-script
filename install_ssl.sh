#!/bin/bash
clear
GREEN='\033[1;32m'; RED='\033[1;31m'; YELLOW='\033[1;33m'; CYAN='\033[1;36m'; NC='\033[0m'

echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║        ${GREEN}INSTALADOR DE SSL REAL (Let's Encrypt)${NC}${CYAN}    ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
echo ""

read -p "Ingresa tu dominio (ej: vps.midominio.com): " DOMAIN
if [[ -z "$DOMAIN" ]]; then
    echo -e "${RED}[ERROR] El dominio es obligatorio.${NC}"
    exit 1
fi

read -p "Ingresa tu correo electrónico: " EMAIL
if [[ -z "$EMAIL" ]]; then
    echo -e "${RED}[ERROR] El correo es obligatorio para Let's Encrypt.${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}[*] Verificando que el dominio apunte a este servidor...${NC}"
SERVER_IP=$(curl -s https://api.ipify.org)
DOMAIN_IP=$(dig +short "$DOMAIN" 2>/dev/null | head -n1)

if [[ "$DOMAIN_IP" != "$SERVER_IP" ]]; then
    echo -e "${RED}[ERROR] El dominio ${DOMAIN} apunta a ${DOMAIN_IP}, pero este servidor es ${SERVER_IP}${NC}"
    echo -e "${YELLOW}Espera 10 minutos a que el DNS se propague e intenta de nuevo.${NC}"
    exit 1
fi
echo -e "${GREEN}[OK] DNS verificado correctamente.${NC}"
echo ""

echo -e "${YELLOW}[*] Deteniendo Nginx para liberar el puerto 80...${NC}"
systemctl stop nginx

echo -e "${YELLOW}[*] Solicitando certificado REAL a Let's Encrypt...${NC}"
echo -e "${CYAN}(Esto puede tardar 1-2 minutos, por favor espera)${NC}"

# Intentar obtener el certificado
certbot certonly --standalone \
    -d "$DOMAIN" \
    --email "$EMAIL" \
    --non-interactive \
    --agree-tos \
    --force-renewal

if [[ $? -eq 0 ]]; then
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║       ¡CERTIFICADO SSL REAL INSTALADO!           ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
    
    # Actualizar Nginx para usar el SSL REAL
    echo -e "${YELLOW}[*] Configurando Nginx con el nuevo certificado...${NC}"
    cat > /etc/nginx/sites-available/oxgi << EOF
# HTTP - Redirigir a HTTPS o servir Non-TLS
server {
    listen 80;
    server_name ${DOMAIN} _;
    location / {
        proxy_pass http://127.0.0.1:2090;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_buffering off;
    }
}

# HTTPS - Puerto 443 con SSL REAL
server {
    listen 443 ssl http2;
    server_name ${DOMAIN} _;
    
    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    
    location / {
        proxy_pass http://127.0.0.1:2090;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_buffering off;
    }
}
EOF
    
    systemctl start nginx
    systemctl reload nginx
    
    # Programar renovación automática
    (crontab -l 2>/dev/null | grep -v "certbot renew") | crontab -
    echo "0 3 * * * certbot renew --quiet && systemctl reload nginx" | crontab -
    
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}CONFIGURACIÓN PARA HTTP CUSTOM / INJECTOR:${NC}"
    echo -e "${CYAN}════════════════════════════════════════════${NC}"
    echo -e "  Host : ${GREEN}${DOMAIN}${NC}"
    echo -e "  Port : ${GREEN}443${NC}"
    echo -e "  Path : ${GREEN}/${NC}"
    echo -e "  SNI  : ${GREEN}${DOMAIN}${NC}"
    echo -e "${CYAN}════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${GREEN}¡Todo listo! Tu WebSocket con SSL REAL está funcionando.${NC}"
else
    echo ""
    echo -e "${RED}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║      FALLÓ LA INSTALACIÓN DEL CERTIFICADO        ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════╝${NC}"
    echo -e "${YELLOW}Causas comunes:${NC}"
    echo "  1. El puerto 80 está bloqueado por tu proveedor de VPS."
    echo "  2. El DNS aún no se ha propagado (espera 15 min)."
    echo "  3. Ya existe un certificado inválido para este dominio."
    echo ""
    echo -e "${CYAN}Iniciando Nginx nuevamente...${NC}"
    systemctl start nginx
fi
