#!/bin/bash

REPO="https://github.com/gitechcode-star/oxgi-vps-script.git"

echo "Actualizando OXGI..."

cd /usr/local

rm -rf oxgi-update

git clone "$REPO" oxgi-update

cp -rf oxgi-update/* oxgi/

chmod +x oxgi/*.sh
chmod +x oxgi/modules/*.sh

rm -rf oxgi-update

echo "Actualización completada."
