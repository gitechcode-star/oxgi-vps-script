#!/bin/bash

REPO_DIR="/usr/local/oxgi"

clear

echo "══════════════════════════════"
echo "      OXGI UPDATER"
echo "══════════════════════════════"
echo

if [ ! -d "$REPO_DIR/.git" ]; then
    echo "[ERROR] Repositorio Git no encontrado."
    echo
    read -p "ENTER para continuar..."
    exit 1
fi

echo "[+] Buscando actualizaciones..."
echo

cd "$REPO_DIR" || exit 1

git fetch origin

LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/main)

if [ "$LOCAL" = "$REMOTE" ]; then
    echo "[OK] Ya tienes la ultima version."
    echo
    read -p "ENTER para continuar..."
    exit 0
fi

echo "[+] Descargando cambios..."
echo

git reset --hard HEAD
git clean -fd

if git pull origin main; then

    chmod +x "$REPO_DIR"/oxgi.sh
    chmod +x "$REPO_DIR"/modules/*.sh

    echo
    echo "[OK] Script actualizado correctamente."
    echo

else

    echo
    echo "[ERROR] No se pudo actualizar."
    echo

fi

read -p "ENTER para continuar..."
