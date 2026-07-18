#!/bin/bash
source /etc/oxgi/config.conf
source /usr/local/oxgi/modules/color.sh
source /usr/local/oxgi/modules/header.sh

install_websocket() {
    echo -e "${INFO} Instalando dependencias de WebSocket..."
    apt-get install -y python3 python3-pip > /dev/null 2>&1
    pip3 install websockets > /dev/null 2>&1

    cat > /usr/local/bin/oxgi-ws << 'EOFWS'
#!/usr/bin/env python3
import asyncio
import websockets
import socket
import sys

SSH_HOST = '127.0.0.1'
SSH_PORT = 22
WS_PORT = 2090

async def handle_client(websocket, path):
    try:
        ssh_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        ssh_socket.connect((SSH_HOST, SSH_PORT))
        ssh_socket.setblocking(0)
        
        async def ws_to_ssh():
            try:
                async for message in websocket:
                    ssh_socket.sendall(message)
                    await asyncio.sleep(0.01)
            except: pass
        
        async def ssh_to_ws():
            try:
                while True:
                    await asyncio.sleep(0.01)
                    try:
                        data = ssh_socket.recv(4096)
                        if data:
                            await websocket.send(data)
                        else:
                            break
                    except BlockingIOError:
                        await asyncio.sleep(0.01)
                        continue
                    except:
                        break
            except: pass
        
        await asyncio.gather(ws_to_ssh(), ssh_to_ws())
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
    finally:
        try: websocket.close()
        except: pass
        try: ssh_socket.close()
        except: pass

async def main():
    async with websockets.serve(handle_client, '0.0.0.0', WS_PORT):
        await asyncio.Future()

if __name__ == '__main__':
    asyncio.run(main())
EOFWS
    chmod +x /usr/local/bin/oxgi-ws

    cat > /etc/systemd/system/oxgi-ws.service << 'EOFSVC'
[Unit]
Description=OXGI WebSocket Service (Python)
After=network.target ssh.service
Wants=ssh.service

[Service]
Type=simple
User=root
ExecStart=/usr/bin/python3 /usr/local/bin/oxgi-ws
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOFSVC

    systemctl daemon-reload
    systemctl enable oxgi-ws > /dev/null 2>&1
    systemctl restart oxgi-ws
    echo -e "${OKEY} WebSocket instalado y configurado en puerto ${WS_BACKEND_PORT}"
}

while true; do
    clear
    show_header
    echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│          ${BOLD}WEBSOCKET MANAGER${NC}"
    echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${NC}"
    echo
    echo -e "${CYAN}[01]${NC} Instalar y Configurar WebSocket"
    echo -e "${CYAN}[02]${NC} Reiniciar WebSocket"
    echo -e "${CYAN}[03]${NC} Estado del Servicio"
    echo
    echo -e "${RED}[00]${NC} Regresar"
    echo
    read -p "Seleccione una opción: " opt
    case $opt in
        1) install_websocket; read -p "ENTER..." ;;
        2) systemctl restart oxgi-ws; echo -e "${OKEY} Reiniciado"; read -p "ENTER..." ;;
        3) systemctl status oxgi-ws --no-pager -l; read -p "ENTER..." ;;
        0) break ;;
        *) echo -e "${RED}Opción inválida${NC}"; sleep 1 ;;
    esac
done
