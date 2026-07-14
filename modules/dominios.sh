#!/bin/bash

CONFIG="/etc/oxgi/config.conf"

[ -f "$CONFIG" ] && source "$CONFIG"

while true
do

clear

echo "══════════════════════════════════════"
echo "              DOMINIOS"
echo "══════════════════════════════════════"
echo
echo " Dominio Actual:"
echo
echo " ${DOMAIN:-No Configurado}"
echo
echo "══════════════════════════════════════"
echo
echo " [1] Cambiar Dominio"
echo " [2] Ver Dominio"
echo
echo " [0] Regresar"
echo

read -p "Seleccione una opcion: " opt

case $opt in

1)

read -p "Nuevo Dominio: " DOMAIN_NEW

if grep -q "^DOMAIN=" "$CONFIG"; then
    sed -i "s|^DOMAIN=.*|DOMAIN=\"$DOMAIN_NEW\"|" "$CONFIG"
else
    echo "DOMAIN=\"$DOMAIN_NEW\"" >> "$CONFIG"
fi

echo
echo "Dominio actualizado."
sleep 2
;;

2)

echo
echo "Dominio Actual:"
echo
echo "${DOMAIN:-No Configurado}"
echo
read -p "ENTER..."
;;

0)
break
;;

*)
echo "Opcion invalida"
sleep 1
;;

esac

source "$CONFIG"

done
