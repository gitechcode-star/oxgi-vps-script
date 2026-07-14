#!/bin/bash

REPO_DIR="/usr/local/oxgi"

clear

echo "══════════════════════════════"
echo "      OXGI UPDATER"
echo "══════════════════════════════"
echo

cd "$REPO_DIR" || exit 1

echo "[+] Sincronizando con GitHub..."
echo

git fetch origin

echo "[+] Aplicando cambios..."
echo

git reset --hard origin/main
git clean -fd

chmod +x oxgi.sh
chmod +x modules/*.sh

echo
echo "[OK] Actualizacion completada."
echo

CURRENT=$(git rev-parse --short HEAD)

echo "Commit actual: $CURRENT"
echo

read -p "ENTER para continuar..."
