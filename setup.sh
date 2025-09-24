#!/bin/bash

set -e

echo "=== Verificando Docker ==="
if ! command -v docker &> /dev/null; then
    echo "Instalando Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    echo "Ejecutando script de instalación de Docker..."
    sh get-docker.sh
    rm get-docker.sh
    if ! command -v docker &> /dev/null; then
        echo "Error: Falló la instalación de Docker."
        exit 1
    fi
    echo "Docker instalado correctamente."
else
    echo "Docker ya está instalado."
fi

echo "\n=== Verificando Docker Compose ==="
if ! command -v docker compose &> /dev/null && ! command -v docker-compose &> /dev/null; then
    echo "Instalando Docker Compose..."
    echo "Actualizando lista de paquetes..."
    sudo apt update
    echo "Instalando plugin docker-compose..."
    sudo apt install -y docker-compose-plugin
    if ! command -v docker compose &> /dev/null; then
        echo "Error: Falló la instalación de Docker Compose."
        exit 1
    fi
    echo "Docker Compose instalado correctamente."
else
    echo "Docker Compose ya está instalado."
fi

echo "\n=== Verificando Python3 y pip ==="
if ! command -v python3 &> /dev/null; then
    echo "Instalando Python3..."
    echo "Actualizando lista de paquetes..."
    sudo apt update
    echo "Instalando python3..."
    sudo apt install -y python3
    if ! command -v python3 &> /dev/null; then
        echo "Error: Falló la instalación de Python3."
        exit 1
    fi
    echo "Python3 instalado correctamente."
else
    echo "Python3 ya está instalado."
fi

if ! command -v pip3 &> /dev/null; then
    echo "Instalando pip3..."
    echo "Actualizando lista de paquetes..."
    sudo apt update
    echo "Instalando python3-pip..."
    sudo apt install -y python3-pip
    if ! command -v pip3 &> /dev/null; then
        echo "Error: Falló la instalación de pip3."
        exit 1
    fi
    echo "pip3 instalado correctamente."
else
    echo "pip3 ya está instalado."
fi

echo "\n=== Instalando python3.10-venv ==="
sudo apt install -y python3.10-venv
echo "python3.10-venv instalado correctamente."

echo "\n=== Configurando entorno virtual ==="
if [ -d "venv" ]; then
    echo "Entorno virtual ya existe. Activando..."
else
    echo "Creando entorno virtual..."
    python3 -m venv venv
fi
echo "Activando entorno virtual..."
source venv/bin/activate

echo "\n=== Instalando dependencias de requirements.txt ==="
if [ -f "requirements.txt" ]; then
    echo "Instalando dependencias de requirements.txt..."
    pip3 install -r requirements.txt
    echo "Dependencias instaladas correctamente."
else
    echo "No se encontró requirements.txt, saltando este paso."
fi

echo "\n=== Verificando Copier ==="
if ! command -v copier &> /dev/null; then
    echo "Instalando Copier..."
    pip3 install copier
    if ! command -v copier &> /dev/null; then
        echo "Error: Falló la instalación de Copier."
        exit 1
    fi
    echo "Copier instalado correctamente."
else
    echo "Copier ya está instalado."
fi

echo "\n=== Verificando carpeta 'app' ==="
if [ ! -d "app" ]; then
    echo "Creando carpeta 'app'..."
    mkdir -p app
    echo "Carpeta 'app' creada."
else
    echo "Carpeta 'app' ya existe."
fi

echo "\n=== Verificando archivo YAML ==="
YAML_FILE="$(pwd)/copier-data-example.yml"
if [ ! -f "$YAML_FILE" ]; then
    echo "Error: Archivo YAML no encontrado en $YAML_FILE."
    exit 1
fi
echo "Archivo YAML encontrado: $YAML_FILE"

echo "\n=== Ejecutando Copier con Doodba Template ==="
echo "Copiando plantilla Doodba..."
copier copy gh:Tecnativa/doodba-copier-template ./app --trust --data-file "$YAML_FILE" --vcs-ref=HEAD --defaults --force
echo "Plantilla Doodba copiada correctamente."

echo "\n=== Cambiando al directorio 'app' ==="
cd app

echo "\n=== Agregando usuario al grupo docker ==="
sudo usermod -aG docker $USER
echo "Usuario agregado al grupo docker (requiere logout/login para aplicar)."

echo "\n=== Ejecutando comandos de configuración de Doodba ==="
sg docker "/bin/bash -c '
echo \"Ejecutando git-aggregate...\"
invoke git-aggregate || echo \"Error en invoke git-aggregate; verifica grupo docker.\"
echo \"Ejecutando img-build...\"
invoke img-build --pull || echo \"Error en img-build.\"
echo \"Ejecutando start...\"
invoke start || echo \"Error en start.\"
echo \"Inicializando base de datos (con demo)...\"
docker compose run --rm odoo --stop-after-init -i base || echo \"Error en inicialización base.\"
echo \"Inicializando base de datos (sin demo)...\"
docker compose run --rm odoo --without-demo=true --stop-after-init -i base || echo \"Error en inicialización sin demo.\"
echo \"Reiniciando servicios...\"
invoke restart || echo \"Error en restart.\"
'"

echo "\n=== Proceso completado ==="
echo "Para uso futuro sin sg, log out y log in para aplicar cambios de grupo docker."
