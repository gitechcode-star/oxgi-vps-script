#!/bin/bash

CONFIG="/etc/oxgi/config.conf"

[ -f "$CONFIG" ] && source "$CONFIG"

while true
do

clear

echo "══════════════════════════════════════"
echo "               PUERTOS"
echo "══════════════════════════════════════"
echo
echo " [1] SSH        : $SSH_PORT"
echo " [2] SSH ALT    : $SSH_PORT_ALT"
echo
echo " [3] HTTP       : $HTTP_PORT"
echo " [4] HTTPS      : $HTTPS_PORT"
echo
echo " [5] WS         : $WS_PORT"
echo
echo " [6] DROPBEAR   : $DROPBEAR_PORT"
echo
echo " [7] BADVPN     : $BADVPN_PORT"
echo
echo " [8] VLESS      : $VLESS_PORT"
echo " [9] VMESS      : $VMESS_PORT"
echo " [10] TROJAN    : $TROJAN_PORT"
echo " [11] SS        : $SS_PORT"
echo
echo " [0] Regresar"
echo
echo "══════════════════════════════════════"

read -p "Seleccione una opcion: " opt

case $opt in

1)
read -p "Nuevo Puerto SSH: " NEW
sed -i "s/^SSH_PORT=.*/SSH_PORT=\"$NEW\"/" $CONFIG
;;

2)
read -p "Nuevo Puerto SSH ALT: " NEW
sed -i "s/^SSH_PORT_ALT=.*/SSH_PORT_ALT=\"$NEW\"/" $CONFIG
;;

3)
read -p "Nuevo Puerto HTTP: " NEW
sed -i "s/^HTTP_PORT=.*/HTTP_PORT=\"$NEW\"/" $CONFIG
;;

4)
read -p "Nuevo Puerto HTTPS: " NEW
sed -i "s/^HTTPS_PORT=.*/HTTPS_PORT=\"$NEW\"/" $CONFIG
;;

5)
read -p "Nuevo Puerto WS: " NEW
sed -i "s/^WS_PORT=.*/WS_PORT=\"$NEW\"/" $CONFIG
;;

6)
read -p "Nuevo Puerto DROPBEAR: " NEW
sed -i "s/^DROPBEAR_PORT=.*/DROPBEAR_PORT=\"$NEW\"/" $CONFIG
;;

7)
read -p "Nuevo Puerto BADVPN: " NEW
sed -i "s/^BADVPN_PORT=.*/BADVPN_PORT=\"$NEW\"/" $CONFIG
;;

8)
read -p "Nuevo Puerto VLESS: " NEW
sed -i "s/^VLESS_PORT=.*/VLESS_PORT=\"$NEW\"/" $CONFIG
;;

9)
read -p "Nuevo Puerto VMESS: " NEW
sed -i "s/^VMESS_PORT=.*/VMESS_PORT=\"$NEW\"/" $CONFIG
;;

10)
read -p "Nuevo Puerto TROJAN: " NEW
sed -i "s/^TROJAN_PORT=.*/TROJAN_PORT=\"$NEW\"/" $CONFIG
;;

11)
read -p "Nuevo Puerto SS: " NEW
sed -i "s/^SS_PORT=.*/SS_PORT=\"$NEW\"/" $CONFIG
;;

0)
break
;;

*)
echo "Opcion invalida"
sleep 1
;;

esac

source $CONFIG

done
