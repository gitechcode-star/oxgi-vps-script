#!/bin/bash

CONFIG="/etc/oxgi/config.conf"

[ -f "$CONFIG" ] && source "$CONFIG"

while true
do

clear

echo "══════════════════════════════════════"
echo "              OXGI VPS"
echo "══════════════════════════════════════"
echo
echo " Version : $VERSION"
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
echo " [1] System"
echo " [2] SSH Manager"
echo " [3] User Manager"
echo " [4] WebSocket Manager"
echo " [5] Nginx Manager"
echo " [6] SSL Manager"
echo " [7] Dropbear Manager"
echo " [8] BadVPN Manager"
echo " [9] V2Ray Manager"
echo " [10] Monitor"
echo
echo " [0] Exit"
echo
echo "══════════════════════════════════════"

read -p "Seleccione una opcion: " opt

case $opt in

1)
bash /usr/local/oxgi/modules/system.sh
;;

2)
bash /usr/local/oxgi/modules/ssh.sh
;;

3)
bash /usr/local/oxgi/modules/users.sh
;;

4)
bash /usr/local/oxgi/modules/websocket.sh
;;

5)
bash /usr/local/oxgi/modules/nginx.sh
;;

6)
bash /usr/local/oxgi/modules/ssl.sh
;;

7)
bash /usr/local/oxgi/modules/dropbear.sh
;;

8)
bash /usr/local/oxgi/modules/badvpn.sh
;;

9)
bash /usr/local/oxgi/modules/v2ray.sh
;;

10)
bash /usr/local/oxgi/modules/monitor.sh
;;

0)
exit
;;

*)
echo "Opcion invalida"
sleep 1
;;

esac

done
