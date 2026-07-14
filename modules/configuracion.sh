#!/bin/bash

CONFIG="/etc/oxgi/config.conf"

[ -f "$CONFIG" ] && source "$CONFIG"

while true
do

clear

echo "══════════════════════════════════════"
echo "            CONFIGURACION"
echo "══════════════════════════════════════"
echo
echo " Dominio : ${DOMAIN:-No Configurado}"
echo
echo " SSH      : $SSH_PORT,$SSH_PORT_ALT"
echo " HTTP     : $HTTP_PORT"
echo " HTTPS    : $HTTPS_PORT"
echo " WS       : $WS_PORT"
echo " DROPBEAR : $DROPBEAR_PORT"
echo " BADVPN   : $BADVPN_PORT"
echo
echo "══════════════════════════════════════"
echo
echo " [1] Nginx Manager"
echo " [2] SSL Manager"
echo " [3] WebSocket Manager"
echo " [4] Dropbear Manager"
echo " [5] BadVPN Manager"
echo " [6] Firewall Manager"
echo " [7] Puertos"
echo " [8] Dominios"
echo
echo " [0] Regresar"
echo
echo "══════════════════════════════════════"

read -p "Seleccione una opcion: " opt

case $opt in

1)
bash /usr/local/oxgi/modules/nginx.sh
;;

2)
bash /usr/local/oxgi/modules/ssl.sh
;;

3)
bash /usr/local/oxgi/modules/websocket.sh
;;

4)
bash /usr/local/oxgi/modules/dropbear.sh
;;

5)
bash /usr/local/oxgi/modules/badvpn.sh
;;

6)
bash /usr/local/oxgi/modules/firewall.sh
;;

7)
bash /usr/local/oxgi/modules/puertos.sh
;;

8)
bash /usr/local/oxgi/modules/dominios.sh
;;

0)
break
;;

*)
echo
echo "Opcion invalida"
sleep 1
;;

esac

done
