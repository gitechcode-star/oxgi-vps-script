#!/bin/bash

clear

echo "
==============================
        OXGI VPS - v1.0.0
==============================
 DESARROLLADOR:
 @CodeNex_oficial
==============================
"

if [[ $EUID -ne 0 ]]; then
    echo "Ejecuta como root"
    exit 1
fi


OS=$(lsb_release -rs)

if [[ "$OS" != "22.04" ]]; then
    echo "Este script solo funciona en Ubuntu 22.04"
    exit 1
fi


echo "[+] Actualizando sistema..."

apt update -y
apt upgrade -y


echo "[+] Instalando dependencias..."

apt install -y \
curl \
wget \
git \
nano \
sudo \
ufw \
net-tools \
python3 \
python3-pip \
openssl \
certbot \
unzip \
jq \
cron \
screen


echo "[+] Creando directorios..."

mkdir -p /etc/oxgi/{users,v2ray,logs,config,data}

mkdir -p /usr/local/oxgi/modules


echo "1.0.0" > /usr/local/oxgi/version


echo "[+] Configurando SSH..."


cp /etc/ssh/sshd_config \
/etc/ssh/sshd_config.backup


grep -q "Port 3303" /etc/ssh/sshd_config || {

echo "
Port 22
Port 3303
" >> /etc/ssh/sshd_config

}


systemctl restart ssh


echo "[+] Instalando Nginx..."

apt install nginx -y


systemctl enable nginx
systemctl restart nginx



echo "[+] Instalando Dropbear..."

apt install dropbear -y


cat >/etc/default/dropbear <<EOF

NO_START=0
DROPBEAR_PORT=442
DROPBEAR_EXTRA_ARGS="-p 442"

EOF


systemctl enable dropbear
systemctl restart dropbear



echo "[+] Instalando BadVPN..."


wget -q https://github.com/ambrop72/badvpn/releases/download/1.999.130/badvpn-1.999.130.tar.gz

tar xzf badvpn-1.999.130.tar.gz

cd badvpn-1.999.130

mkdir build

cd build

cmake .. -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1

make

cp bin/badvpn-udpgw /usr/local/bin/badvpn

cd /

rm -rf badvpn*



cat >/etc/systemd/system/badvpn.service <<EOF

[Unit]
Description=BadVPN UDPGW

After=network.target


[Service]

ExecStart=/usr/local/bin/badvpn \
--listen-addr 0.0.0.0:7300

Restart=always


[Install]

WantedBy=multi-user.target

EOF


systemctl daemon-reload

systemctl enable badvpn

systemctl restart badvpn



echo "[+] Creando WebSocket OXGI..."


cat >/usr/local/bin/oxgi-proxy.py <<EOF

import socketserver


class Proxy(socketserver.StreamRequestHandler):

    def handle(self):

        data=self.rfile.readline()

        if data:

            self.wfile.write(
            b"HTTP/1.1 101 Switching Protocols\\r\\n"
            b"Connection: Upgrade\\r\\n"
            b"Upgrade: websocket\\r\\n\\r\\n"
            )


server=socketserver.ThreadingTCPServer(
("127.0.0.1",700),
Proxy
)

server.serve_forever()

EOF



cat >/etc/systemd/system/oxgi-ws.service <<EOF

[Unit]

Description=OXGI WebSocket

After=network.target


[Service]

ExecStart=/usr/bin/python3 /usr/local/bin/oxgi-proxy.py

Restart=always


[Install]

WantedBy=multi-user.target

EOF


systemctl daemon-reload

systemctl enable oxgi-ws

systemctl restart oxgi-ws



echo "[+] Instalando menu OXGI..."

touch /usr/local/oxgi/oxgi.sh

chmod +x /usr/local/oxgi/oxgi.sh


echo "

==============================
 OXGI VPS INSTALADO
==============================

SSH:
22
3303

WS:
80

SSL:
443

Proxy:
700

BadVPN:
7300

Reinicia el VPS

==============================

"

