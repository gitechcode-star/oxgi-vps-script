
#!/bin/bash

while true
do
clear

echo "══════════════════════════════"
echo "       USER MANAGER"
echo "══════════════════════════════"
echo
echo "[1] Crear Usuario"
echo "[2] Eliminar Usuario"
echo "[3] Renovar Usuario"
echo "[4] Usuarios Online"
echo
echo "[0] Regresar"
echo

read -p "Seleccione una opción: " opt

case $opt in

1)
echo "Crear Usuario"
read -p "ENTER..."
;;

2)
echo "Eliminar Usuario"
read -p "ENTER..."
;;

3)
echo "Renovar Usuario"
read -p "ENTER..."
;;

4)
echo "Usuarios Online"
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
