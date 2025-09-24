#!/bin/bash

set -e

echo "=== Verificando Docker ==="
if ! command -v docker &> /dev/null; then
    echo "Docker no encontrado. Instalando..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    if ! command -v docker &> /dev/null; then
        echo "Error: Falló la instalación de Docker."
        exit 1
    fi
else
    echo "Docker ya está instalado."
fi

echo "\n=== Verificando Docker Compose ==="
if ! command -v docker compose &> /dev/null && ! command -v docker-compose &> /dev/null; then
    echo "Docker Compose no encontrado. Instalando..."
    sudo apt update
    sudo apt install -y docker-compose-plugin
    if ! command -v docker compose &> /dev/null; then
        echo "Error: Falló la instalación de Docker Compose."
        exit 1
    fi
else
    echo "Docker Compose ya está instalado."
fi

echo "\n=== Verificando Python3 y pip ==="
if ! command -v python3 &> /dev/null; then
    echo "Python3 no encontrado. Instalando..."
    sudo apt update
    sudo apt install -y python3
    if ! command -v python3 &> /dev/null; then
        echo "Error: Falló la instalación de Python3."
        exit 1
    fi
else
    echo "Python3 ya está instalado."
fi

if ! command -v pip3 &> /dev/null; then
    echo "pip3 no encontrado. Instalando..."
    sudo apt install -y python3-pip
    if ! command -v pip3 &> /dev/null; then
        echo "Error: Falló la instalación de pip3."
        exit 1
    fi
else
    echo "pip3 ya está instalado."
fi

sudo apt install -y python3.10-venv

if [ -d "venv" ]; then
    echo "Entorno virtual ya existe. Activando..."
else
    python3 -m venv venv
fi
source venv/bin/activate

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
    if ! command -v copier &> /dev/null; then
        echo "Error: Falló la instalación de Copier."
        exit 1
    fi
else
    echo "Copier ya está instalado."
fi

echo "\n=== Verificando carpeta 'app' ==="
if [ ! -d "app" ]; then
    mkdir -p app
fi

echo "\n=== Verificando archivo YAML ==="
YAML_FILE="$(pwd)/copier-data-example.yml"
if [ ! -f "$YAML_FILE" ]; then
    echo "Error: Archivo YAML no encontrado en $YAML_FILE. Crea el archivo y vuelve a intentarlo."
    exit 1
fi
echo "Archivo YAML encontrado: $YAML_FILE"

echo "\n=== Ejecutando Copier con Doodba Template ==="
copier copy gh:Tecnativa/doodba-copier-template ./app --trust --data-file "$YAML_FILE" --vcs-ref=HEAD --defaults --force

cd app

echo "\n=== Agregando usuario a grupo docker (requiere logout/login para aplicar) ==="
sudo usermod -aG docker $USER

sg docker "/bin/bash -c '
invoke git-aggregate || echo \"Error en invoke git-aggregate; verifica grupo docker.\"
invoke img-build --pull || echo \"Error en img-build.\"
invoke start || echo \"Error en start.\"
docker compose run --rm odoo --stop-after-init -i base || echo \"Error en inicialización base.\"
docker compose run --rm odoo --without-demo=true --stop-after-init -i base || echo \"Error en inicialización sin demo.\"
invoke restart || echo \"Error en restart.\"
'"

echo "=== Proceso completado. Para uso futuro sin sg, log out y log in para aplicar cambios de grupo docker. ==="
