
#!/bin/bash

while true
do
clear

echo "══════════════════════════════"
echo "       NGINX MANAGER"
echo "══════════════════════════════"
echo
echo "[1] Instalar Nginx"
echo "[2] Reiniciar Nginx"
echo "[3] Estado Nginx"
echo
echo "[0] Regresar"
echo

read -p "Seleccione una opción: " opt

case $opt in

1)
echo "Instalar Nginx"
read -p "ENTER..."
;;

2)
echo "Reiniciar Nginx"
read -p "ENTER..."
;;

3)
echo "Estado Nginx"
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
