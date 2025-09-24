#!/bin/bash

set -e

echo "=== Verificando Docker ==="
if ! command -v docker &> /dev/null; then
    echo "Docker no encontrado. Instalando..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
else
    echo "Docker ya está instalado."
fi

echo "\n=== Verificando Docker Compose ==="
if ! command -v docker compose &> /dev/null && ! command -v docker-compose &> /dev/null; then
    echo "Docker Compose no encontrado. Instalando..."
    sudo apt update
    sudo apt install -y docker-compose-plugin
else
    echo "Docker Compose ya está instalado."
fi

echo "\n=== Verificando Python3 y pip ==="
if ! command -v python3 &> /dev/null; then
    echo "Python3 no encontrado. Instalando..."
    sudo apt update
    sudo apt install -y python3
else
    echo "Python3 ya está instalado."
fi

if ! command -v pip3 &> /dev/null; then
    echo "pip3 no encontrado. Instalando..."
    sudo apt install -y python3-pip
else
    echo "pip3 ya está instalado."
fi


echo "\n=== Instalando dependencias de requirements.txt (si existe) ==="
if [ -f "requirements.txt" ]; then
    pip3 install -r requirements.txt
else
    echo "No se encontró requirements.txt, saltando este paso."
fi

echo "\n=== Verificando Copier ==="
if ! command -v copier &> /dev/null; then
    echo "Copier no encontrado. Instalando..."
    pip3 install copier
else
    echo "Copier ya está instalado."
fi

echo "\n=== Verificando carpeta 'app' ==="
if [ -d "app" ]; then
    if [ -z "$(ls -A app)" ]; then
        echo "La carpeta 'app' existe y está vacía. Usaremos esta."
    else
        echo "La carpeta 'app' existe y no está vacía. Crearemos una nueva carpeta."
        mkdir -p app
    fi
else
    echo "La carpeta 'app' no existe. Creándola..."
    mkdir -p app
fi

echo "\n=== Ejecutando Copier con Doodba Template ==="
copier copy gh:Tecnativa/doodba-copier-template ./app --trust --data-file ./copier-data-example.yml

cd app

sudo usermod -aG docker $USER

newgrp docker

invoke git-aggregate

invoke img-build --pull

invoke start

docker-compose run --rm odoo --stop-after-init -i base

docker-compose run --rm odoo --without-demo=true --stop-after-init -i base

invoke restart


echo "=== Proceso completado ==="