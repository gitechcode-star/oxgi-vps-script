#!/bin/bash

CONFIG="/etc/oxgi/config.conf"

[ -f "$CONFIG" ] && source "$CONFIG"

while true
do

clear

# Recargar configuración cada vez que vuelve al menú
[ -f "$CONFIG" ] && source "$CONFIG"

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
echo " [1] SSH Manager"
echo " [2] V2Ray Manager"
echo " [3] Monitor"
echo
echo " [4] Configuración"
echo " [5] Actualizar Script"
echo
echo " [0] Exit"
echo
echo "══════════════════════════════════════"

read -p "Seleccione una opcion: " opt

case $opt in

1)
bash /usr/local/oxgi/modules/ssh.sh
;;

2)
bash /usr/local/oxgi/modules/v2ray.sh
;;

3)
bash /usr/local/oxgi/modules/monitor.sh
;;

4)
bash /usr/local/oxgi/modules/configuracion.sh
;;

5)
bash /usr/local/oxgi/modules/updater.sh
;;

0)
clear
echo
echo "Gracias por usar OXGI VPS"
echo
exit 0
;;

*)
echo
echo "Opción inválida"
sleep 1
;;

esac

done
