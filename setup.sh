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
    pip3 install --user -r requirements.txt  # Use --user to avoid permission issues
else
    echo "No se encontró requirements.txt, saltando este paso."
fi

echo "\n=== Verificando Copier ==="
if ! command -v copier &> /dev/null; then
    echo "Copier no encontrado. Instalando..."
    pip3 install --user copier
else
    echo "Copier ya está instalado."
fi

echo "\n=== Verificando carpeta 'app' ==="
if [ -d "app" ]; then
    if [ -z "$(ls -A app)" ]; then
        echo "La carpeta 'app' existe y está vacía. Usaremos esta."
    else
        echo "La carpeta 'app' existe y no está vacía."
        # Opcional: Vaciarla (descomenta si quieres, pero cuidado: borra todo!)
        # rm -rf app/*
        # echo "Carpeta 'app' vaciada."
        # O crea una nueva, pero por ahora, usamos la existente (agrega --force en Copier si necesitas sobrescribir)
        echo "Usaremos la existente (agrega lógica para manejar si es necesario)."
    fi
else
    echo "La carpeta 'app' no existe. Creándola..."
    mkdir -p app
fi

echo "\n=== Verificando archivo YAML ==="
YAML_FILE="$(pwd)/copier-data-example.yml"
echo "Directorio actual: $(pwd)"  # Depuración
if [ -f "$YAML_FILE" ]; then
    echo "Archivo YAML encontrado: $YAML_FILE"
else
    echo "Error: Archivo YAML no encontrado en $YAML_FILE. Crea el archivo y vuelve a intentarlo."
    exit 1
fi

echo "\n=== Ejecutando Copier con Doodba Template ==="
copier copy gh:Tecnativa/doodba-copier-template ./app --trust --data-file "$YAML_FILE" --vcs-ref=HEAD --defaults --force  # Agregado --force para sobrescribir si app no vacía

cd app

echo "\n=== Agregando usuario a grupo docker (requiere logout/login para aplicar) ==="
sudo usermod -aG docker $USER

# Ejecuta comandos restantes con sg para usar grupo docker sin newgrp
sg docker "invoke git-aggregate" || echo "Error en invoke git-aggregate; verifica grupo docker."
sg docker "invoke img-build --pull" || echo "Error en img-build."
sg docker "invoke start" || echo "Error en start."
sg docker "docker-compose run --rm odoo --stop-after-init -i base" || echo "Error en inicialización base."
sg docker "docker-compose run --rm odoo --without-demo=true --stop-after-init -i base" || echo "Error en inicialización sin demo."
sg docker "invoke restart" || echo "Error en restart."

echo "=== Proceso completado. Log out y log in para aplicar cambios de grupo docker. ==="
