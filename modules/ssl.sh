
#!/bin/bash

while true
do
clear

echo "══════════════════════════════"
echo "        SSL MANAGER"
echo "══════════════════════════════"
echo
echo "[1] Instalar SSL"
echo "[2] Renovar SSL"
echo "[3] Estado SSL"
echo
echo "[0] Regresar"
echo

read -p "Seleccione una opción: " opt

case $opt in

1)
echo "Instalar SSL"
read -p "ENTER..."
;;

2)
echo "Renovar SSL"
read -p "ENTER..."
;;

3)
echo "Estado SSL"
read -p "ENTER..."
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
