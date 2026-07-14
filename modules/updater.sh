#!/bin/bash

REPO_DIR="/usr/local/oxgi"

clear

echo "══════════════════════════════════════"
echo "          OXGI UPDATER"
echo "══════════════════════════════════════"
echo

cd "$REPO_DIR" || exit 1

echo "[+] Buscando actualizaciones..."
echo

git fetch origin

LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/main)

if [ "$LOCAL" = "$REMOTE" ]; then
    echo "[✓] Ya tienes la última versión."
    echo
    read -p "ENTER para continuar..."
    exit 0
fi

echo "[+] Aplicando cambios..."
echo

git reset --hard origin/main
git clean -fd

chmod +x oxgi.sh
chmod +x modules/*.sh

CURRENT=$(git rev-parse --short HEAD)

echo
echo "[✓] Script actualizado correctamente"
echo
echo "Commit actual: $CURRENT"
echo

read -p "ENTER para continuar..."
