#!/bin/bash

REPO="https://github.com/gitechcode-star/oxgi-vps-script.git"
INSTALL_DIR="/usr/local/oxgi"

clear

echo "══════════════════════════════"
echo "      OXGI UPDATER"
echo "══════════════════════════════"
echo

echo "[+] Actualizando OXGI..."
echo

if [ ! -d "$INSTALL_DIR/.git" ]; then
    echo "[ERROR] OXGI no fue instalado desde Git."
    echo
    read -p "ENTER para continuar..."
    exit 1
fi

cd "$INSTALL_DIR" || exit

git reset --hard HEAD
git clean -fd

git pull origin main

chmod +x oxgi.sh
chmod +x modules/*.sh

echo
echo "[OK] Script actualizado correctamente."
echo

read -p "ENTER para continuar..."
