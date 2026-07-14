#!/bin/bash

while true
do

clear

echo "══════════════════════════════"
echo "      CONFIGURACION"
echo "══════════════════════════════"
echo
echo " [1] Nginx Manager"
echo " [2] SSL Manager"
echo " [3] WebSocket Manager"
echo " [4] Dropbear Manager"
echo " [5] BadVPN Manager"
echo " [6] Firewall Manager"
echo " [7] Proxy Manager"
echo " [8] Puertos"
echo " [9] Dominios"
echo
echo " [0] Regresar"
echo

read -p "Seleccione una opcion: " opt

case $opt in

1) bash /usr/local/oxgi/modules/config/nginx.sh ;;
2) bash /usr/local/oxgi/modules/config/ssl.sh ;;
3) bash /usr/local/oxgi/modules/config/websocket.sh ;;
4) bash /usr/local/oxgi/modules/config/dropbear.sh ;;
5) bash /usr/local/oxgi/modules/config/badvpn.sh ;;
6) bash /usr/local/oxgi/modules/config/firewall.sh ;;
7) bash /usr/local/oxgi/modules/config/proxy.sh ;;
8) bash /usr/local/oxgi/modules/config/puertos.sh ;;
9) bash /usr/local/oxgi/modules/config/dominios.sh ;;

0) break ;;

*)
echo "Opcion invalida"
sleep 1
;;

esac

done
