
#!/bin/bash

while true
do
clear

echo "══════════════════════════════"
echo "      DROPBEAR MANAGER"
echo "══════════════════════════════"
echo
echo "[1] Instalar Dropbear"
echo "[2] Reiniciar Dropbear"
echo "[3] Estado Dropbear"
echo
echo "[0] Regresar"
echo

read -p "Seleccione una opción: " opt

case $opt in

1)
echo "Instalar Dropbear"
read -p "ENTER..."
;;

2)
echo "Reiniciar Dropbear"
read -p "ENTER..."
;;

3)
echo "Estado Dropbear"
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
