#!/bin/bash

while true
do
clear

echo "══════════════════════════════"
echo "         SYSTEM"
echo "══════════════════════════════"
echo
echo "[1] Información del Sistema"
echo "[2] Uso de RAM"
echo "[3] Uso de Disco"
echo "[4] Uptime"
echo
echo "[0] Regresar"
echo

read -p "Seleccione una opción: " opt

case $opt in
1)
echo
echo "SYSTEM INFO"
read -p "ENTER para continuar..."
;;

2)
echo
echo "RAM INFO"
read -p "ENTER para continuar..."
;;

3)
echo
echo "DISK INFO"
read -p "ENTER para continuar..."
;;

4)
echo
echo "UPTIME INFO"
read -p "ENTER para continuar..."
;;

0)
break
;;

*)
echo "Opción inválida"
sleep 1
;;

esac

done
