#!/bin/bash

CONFIG="/etc/oxgi/config.conf"
VERSION_FILE="/etc/oxgi/version.conf"

[ -f "$CONFIG" ] && source "$CONFIG"
[ -f "$VERSION_FILE" ] && source "$VERSION_FILE"

source /usr/local/oxgi/modules/header.sh

while true
do

# Recargar configuración y versión
[ -f "$CONFIG" ] && source "$CONFIG"
[ -f "$VERSION_FILE" ] && source "$VERSION_FILE"

show_header

printf "%-20s %-20s\n" "SSH      : $SSH_PORT,$SSH_PORT_ALT" "HTTP     : $HTTP_PORT"
printf "%-20s %-20s\n" "HTTPS    : $HTTPS_PORT" "WS       : $WS_PORT"
printf "%-20s %-20s\n" "DROPBEAR : $DROPBEAR_PORT" "BADVPN   : $BADVPN_PORT"

echo
echo "══════════════════════════════════════════════════════════════"
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
echo "══════════════════════════════════════════════════════════════"
echo

read -p "Seleccione una opción: " opt

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
