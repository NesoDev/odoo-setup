#!/bin/bash
# Script de Despliegue de Odoo Doodba en Modo Producción
# Asegura la instalación de dependencias, copia la plantilla, construye e inicia en modo prod.

set -e

# --- Configuración de Variables ---
APP_DIR="app"
YAML_FILE="$(pwd)/copier-data-example.yml"
DOODBA_TEMPLATE="gh:Tecnativa/doodba-copier-template"

echo "=== 1. Verificación e Instalación de Dependencias del Sistema ==="

# Función auxiliar para instalar paquetes
install_package() {
    PACKAGE_CMD=$1
    PACKAGE_NAME=$2
    INSTALL_CMD=$3
    if ! command -v "$PACKAGE_CMD" &> /dev/null; then
        echo "Instalando $PACKAGE_NAME..."
        sudo apt update > /dev/null 2>&1
        sudo apt install -y $INSTALL_CMD > /dev/null 2>&1
        if ! command -v "$PACKAGE_CMD" &> /dev/null; then
            echo "Error: Falló la instalación de $PACKAGE_NAME."
            exit 1
        fi
        echo "$PACKAGE_NAME instalado correctamente."
    else
        echo "$PACKAGE_NAME ya está instalado."
    fi
}

install_package docker "Docker" "docker.io"
install_package docker\ compose "Docker Compose" "docker-compose-plugin"
install_package python3 "Python3" "python3"
install_package pip3 "pip3" "python3-pip"
install_package python3.10-venv "python3.10-venv" "python3.10-venv"

# --- 2. Configuración e Instalación de Entorno Virtual y Python ---

echo "\n=== 2. Configurando Entorno Virtual y Dependencias Python ==="

if [ ! -d "venv" ]; then
    echo "Creando entorno virtual..."
    python3 -m venv venv
fi
echo "Activando entorno virtual..."
source venv/bin/activate

if [ -f "requirements.txt" ]; then
    echo "Instalando dependencias de requirements.txt..."
    pip3 install -r requirements.txt
    echo "Dependencias instaladas correctamente."
else
    echo "No se encontró requirements.txt. Instalando invoke y copier directamente."
    pip3 install invoke copier
fi

# --- 3. Generación del Proyecto Doodba ---

echo "\n=== 3. Generación del Proyecto Doodba ==="

if [ ! -d "$APP_DIR" ]; then
    echo "Creando carpeta '$APP_DIR'..."
    mkdir -p "$APP_DIR"
fi

if [ ! -f "$YAML_FILE" ]; then
    echo "Error: Archivo YAML no encontrado en $YAML_FILE."
    exit 1
fi
echo "Archivo YAML encontrado: $YAML_FILE"

echo "Copiando plantilla Doodba..."
copier copy "$DOODBA_TEMPLATE" "./$APP_DIR" --trust --data-file "$YAML_FILE" --vcs-ref=HEAD --defaults --force
echo "Plantilla Doodba copiada correctamente."

# --- 4. Preparación de Permisos de Docker ---

echo "\n=== 4. Preparación de Permisos de Docker ==="
if groups $USER | grep &>/dev/null '\bdocker\b'; then
    echo "Usuario ya en el grupo 'docker'. Continuamos."
else
    echo "Agregando usuario '$USER' al grupo 'docker'..."
    sudo usermod -aG docker $USER
    echo "⚠️ ADVERTENCIA: Debes cerrar la sesión y volver a iniciar para que los nuevos"
    echo "permisos del grupo 'docker' surtan efecto. Por seguridad y simplicidad, todos"
    echo "los comandos de Docker/Invoke se ejecutarán con 'sudo' por ahora."
fi

# --- 5. Ejecución de Tareas de Doodba (Modo Producción) ---

echo "\n=== 5. Ejecutando Tareas de Doodba (Modo Producción) ==="
cd "$APP_DIR"

# Limpieza inicial para evitar errores de red huérfana
echo "Limpiando entornos anteriores para evitar conflictos de red..."
sudo docker compose -f devel.yaml -f common.yaml down --remove-orphans > /dev/null 2>&1 || true
sudo docker compose -f prod.yaml -f common.yaml down --remove-orphans > /dev/null 2>&1 || true

echo "Ejecutando git-aggregate para la agregación de módulos..."
invoke git-aggregate

echo "Ejecutando img-build --pull para construir las imágenes del proyecto..."
invoke img-build --pull

echo "Iniciando servicios en MODO PRODUCCIÓN (Traefik, Odoo, Postgres)..."
# Usamos directamente docker compose con prod.yaml para asegurar el modo prod
sudo docker compose -f prod.yaml up -d

echo "\n=== 6. Post-despliegue y Pruebas (Opcional) ==="

# Esperar un poco a que Odoo se levante
echo "Esperando 10 segundos para que Odoo y Traefik se inicialicen..."
sleep 10

echo "Verificando el estado de los contenedores de producción:"
sudo docker compose -f prod.yaml ps

echo "\n=== Proceso de Despliegue en Producción Completado ==="
echo "La aplicación Odoo ahora debería estar disponible a través de Traefik en los puertos 80/443."
echo "Asegúrate de que:"
echo "1. Tu Dominio apunte a la IP de Lightsail."
echo "2. Los puertos 80 y 443 estén abiertos en el Firewall de Lightsail."
echo "3. Las variables de entorno de Traefik (ej. DOMAIN_NAME) en .env o prod.yaml estén configuradas correctamente."
echo "Para detener los servicios, usa: sudo docker compose -f prod.yaml down"
