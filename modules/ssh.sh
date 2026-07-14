#!/bin/bash

source /usr/local/oxgi/modules/color.sh
source /usr/local/oxgi/modules/header.sh

while true
do

show_header

echo -e "${GREEN}SSH MANAGER${NC}"
echo

echo -e "${CYAN}[1]${NC} Crear Usuario SSH"
echo -e "${CYAN}[2]${NC} Eliminar Usuario SSH"
echo -e "${CYAN}[3]${NC} Renovar Usuario SSH"
echo -e "${CYAN}[4]${NC} Cambiar Contraseña"
echo -e "${CYAN}[5]${NC} Usuarios Online"
echo -e "${CYAN}[6]${NC} Lista de Usuarios"
echo -e "${CYAN}[7]${NC} Eliminar Expirados"

echo
echo -e "${RED}[0]${NC} Regresar"
echo

echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
echo

read -p "Seleccione una opción: " opt

case $opt in

1)
clear
show_header
echo -e "${YELLOW}Crear Usuario SSH${NC}"
echo
echo "Función en desarrollo..."
echo
read -p "ENTER para continuar..."
;;

2)
clear
show_header
echo -e "${YELLOW}Eliminar Usuario SSH${NC}"
echo
echo "Función en desarrollo..."
echo
read -p "ENTER para continuar..."
;;

3)
clear
show_header
echo -e "${YELLOW}Renovar Usuario SSH${NC}"
echo
echo "Función en desarrollo..."
echo
read -p "ENTER para continuar..."
;;

4)
clear
show_header
echo -e "${YELLOW}Cambiar Contraseña${NC}"
echo
echo "Función en desarrollo..."
echo
read -p "ENTER para continuar..."
;;

5)
clear
show_header
echo -e "${YELLOW}Usuarios Online${NC}"
echo
echo "Función en desarrollo..."
echo
read -p "ENTER para continuar..."
;;

6)
clear
show_header
echo -e "${YELLOW}Lista de Usuarios${NC}"
echo
echo "Función en desarrollo..."
echo
read -p "ENTER para continuar..."
;;

7)
clear
show_header
echo -e "${YELLOW}Eliminar Expirados${NC}"
echo
echo "Función en desarrollo..."
echo
read -p "ENTER para continuar..."
;;

0)
break
;;

*)
echo
echo -e "${RED}Opción inválida${NC}"
sleep 1
;;

esac

done
