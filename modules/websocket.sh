
#!/bin/bash

while true
do
clear

echo "══════════════════════════════"
echo "     WEBSOCKET MANAGER"
echo "══════════════════════════════"
echo
echo "[1] Instalar WebSocket"
echo "[2] Reiniciar WebSocket"
echo "[3] Estado WebSocket"
echo
echo "[0] Regresar"
echo

read -p "Seleccione una opción: " opt

case $opt in

1)
echo "Instalar WebSocket"
read -p "ENTER..."
;;

2)
echo "Reiniciar WebSocket"
read -p "ENTER..."
;;

3)
echo "Estado WebSocket"
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
