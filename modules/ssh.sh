#!/bin/bash

source /usr/local/oxgi/modules/header.sh

while true
do

show_header

echo "SSH MANAGER"
echo
echo " [1] Crear Usuario SSH"
echo " [2] Eliminar Usuario SSH"
echo " [3] Renovar Usuario SSH"
echo " [4] Cambiar Contraseña"
echo " [5] Usuarios Online"
echo " [6] Lista de Usuarios"
echo " [7] Eliminar Expirados"
echo
echo " [0] Regresar"
echo
echo "══════════════════════════════════════════════════════════════"
echo

read -p "Seleccione una opción: " opt

case $opt in

1)
clear
echo
echo "Función en desarrollo:"
echo "Crear Usuario SSH"
echo
read -p "ENTER para continuar..."
;;

2)
clear
echo
echo "Función en desarrollo:"
echo "Eliminar Usuario SSH"
echo
read -p "ENTER para continuar..."
;;

3)
clear
echo
echo "Función en desarrollo:"
echo "Renovar Usuario SSH"
echo
read -p "ENTER para continuar..."
;;

4)
clear
echo
echo "Función en desarrollo:"
echo "Cambiar Contraseña"
echo
read -p "ENTER para continuar..."
;;

5)
clear
echo
echo "Función en desarrollo:"
echo "Usuarios Online"
echo
read -p "ENTER para continuar..."
;;

6)
clear
echo
echo "Función en desarrollo:"
echo "Lista de Usuarios"
echo
read -p "ENTER para continuar..."
;;

7)
clear
echo
echo "Función en desarrollo:"
echo "Eliminar Expirados"
echo
read -p "ENTER para continuar..."
;;

0)
break
;;

*)
echo
echo "Opción inválida"
sleep 1
;;

esac

done
