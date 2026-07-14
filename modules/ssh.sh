
#!/bin/bash

while true
do
clear

echo "══════════════════════════════"
echo "       SSH MANAGER"
echo "══════════════════════════════"
echo
echo "[1] Instalar SSH"
echo "[2] Cambiar Puerto"
echo "[3] Reiniciar SSH"
echo "[4] Estado SSH"
echo
echo "[0] Regresar"
echo

read -p "Seleccione una opción: " opt

case $opt in

1)
echo "Instalar SSH"
read -p "ENTER..."
;;

2)
echo "Cambiar Puerto"
read -p "ENTER..."
;;

3)
echo "Reiniciar SSH"
read -p "ENTER..."
;;

4)
echo "Estado SSH"
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
