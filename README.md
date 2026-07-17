
# install-bootstrap.sh (más seguro)
#!/bin/bash
INSTALLER_URL="https://raw.githubusercontent.com/gitechcode-star/oxgi-vps-script/main/install.sh"

echo " Descargando OXGI VPS Script..."
curl -Ls $INSTALLER_URL -o /tmp/oxgi-install.sh

if [[ $? -eq 0 ]]; then
    echo "🚀 Iniciando instalación..."
    bash /tmp/oxgi-install.sh
    rm -f /tmp/oxgi-install.sh
else
    echo "❌ Error al descargar"
    exit 1
fi
