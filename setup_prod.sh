#!/bin/bash

set -e

# Array para almacenar el estado de cada comando
declare -A COMMAND_STATUS
COMMAND_ORDER=()

# Función para registrar el estado de un comando
log_status() {
    local command_name="$1"
    local status="$2"
    COMMAND_STATUS["$command_name"]="$status"
    COMMAND_ORDER+=("$command_name")
}

# Función para mostrar el resumen final
show_summary() {
    echo -e "\n"
    echo "=========================================="
    echo "       RESUMEN DE EJECUCIÓN"
    echo "=========================================="
    echo ""
    
    local success_count=0
    local error_count=0
    local skip_count=0
    
    for cmd in "${COMMAND_ORDER[@]}"; do
        local status="${COMMAND_STATUS[$cmd]}"
        local symbol=""
        local color=""
        
        case "$status" in
            "SUCCESS")
                symbol="✓"
                color="\033[0;32m"
                ((success_count++))
                ;;
            "ERROR")
                symbol="✗"
                color="\033[0;31m"
                ((error_count++))
                ;;
            "SKIPPED")
                symbol="○"
                color="\033[0;33m"
                ((skip_count++))
                ;;
        esac
        
        printf "${color}[${symbol}] %-50s %s\033[0m\n" "$cmd" "$status"
    done
    
    echo ""
    echo "=========================================="
    printf "Total: %d | " "${#COMMAND_ORDER[@]}"
    printf "\033[0;32mÉxitos: %d\033[0m | " "$success_count"
    printf "\033[0;31mErrores: %d\033[0m | " "$error_count"
    printf "\033[0;33mOmitidos: %d\033[0m\n" "$skip_count"
    echo "=========================================="
}

echo "=== Verificando Docker ==="
if ! command -v docker &> /dev/null; then
    echo "Instalando Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    echo "Ejecutando script de instalación de Docker..."
    sh get-docker.sh
    rm get-docker.sh
    if ! command -v docker &> /dev/null; then
        echo "Error: Falló la instalación de Docker."
        log_status "Instalación de Docker" "ERROR"
        exit 1
    fi
    echo "Docker instalado correctamente."
    log_status "Instalación de Docker" "SUCCESS"
else
    echo "Docker ya está instalado."
    log_status "Verificación de Docker" "SKIPPED"
fi

echo -e "\n=== Verificando Docker Compose ==="
if ! docker compose version &> /dev/null && ! command -v docker-compose &> /dev/null; then
    echo "Instalando Docker Compose..."
    
    # Agregar repositorio oficial de Docker
    echo "Configurando repositorio de Docker..."
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl gnupg lsb-release
    
    # Agregar la clave GPG oficial de Docker
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Configurar el repositorio
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Actualizar e instalar
    sudo apt-get update
    sudo apt-get install -y docker-compose-plugin
    
    if ! docker compose version &> /dev/null; then
        echo "Error: Falló la instalación de Docker Compose."
        log_status "Instalación de Docker Compose" "ERROR"
        exit 1
    fi
    echo "Docker Compose instalado correctamente."
    log_status "Instalación de Docker Compose" "SUCCESS"
else
    echo "Docker Compose ya está instalado."
    log_status "Verificación de Docker Compose" "SKIPPED"
fi

echo -e "\n=== Verificando Python3 y pip ==="
if ! command -v python3 &> /dev/null; then
    echo "Instalando Python3..."
    sudo apt update
    sudo apt install -y python3
    if ! command -v python3 &> /dev/null; then
        echo "Error: Falló la instalación de Python3."
        log_status "Instalación de Python3" "ERROR"
        exit 1
    fi
    echo "Python3 instalado correctamente."
    log_status "Instalación de Python3" "SUCCESS"
else
    echo "Python3 ya está instalado."
    log_status "Verificación de Python3" "SKIPPED"
fi

if ! command -v pip3 &> /dev/null; then
    echo "Instalando pip3..."
    sudo apt update
    sudo apt install -y python3-pip
    if ! command -v pip3 &> /dev/null; then
        echo "Error: Falló la instalación de pip3."
        log_status "Instalación de pip3" "ERROR"
        exit 1
    fi
    echo "pip3 instalado correctamente."
    log_status "Instalación de pip3" "SUCCESS"
else
    echo "pip3 ya está instalado."
    log_status "Verificación de pip3" "SKIPPED"
fi

echo -e "\n=== Instalando python3.10-venv ==="
sudo apt install -y python3.10-venv
log_status "Instalación de python3.10-venv" "SUCCESS"
echo "python3.10-venv instalado correctamente."

echo -e "\n=== Configurando entorno virtual ==="
if [ -d "venv" ]; then
    echo "Entorno virtual ya existe. Activando..."
    log_status "Creación de entorno virtual" "SKIPPED"
else
    echo "Creando entorno virtual..."
    python3 -m venv venv
    log_status "Creación de entorno virtual" "SUCCESS"
fi
echo "Activando entorno virtual..."
source venv/bin/activate

echo -e "\n=== Instalando dependencias de requirements.txt ==="
if [ -f "requirements.txt" ]; then
    echo "Instalando dependencias de requirements.txt..."
    pip3 install -r requirements.txt
    log_status "Instalación de requirements.txt" "SUCCESS"
    echo "Dependencias instaladas correctamente."
else
    echo "No se encontró requirements.txt, saltando este paso."
    log_status "Instalación de requirements.txt" "SKIPPED"
fi

echo -e "\n=== Verificando Copier ==="
if ! command -v copier &> /dev/null; then
    echo "Instalando Copier..."
    pip3 install copier
    if ! command -v copier &> /dev/null; then
        echo "Error: Falló la instalación de Copier."
        log_status "Instalación de Copier" "ERROR"
        exit 1
    fi
    echo "Copier instalado correctamente."
    log_status "Instalación de Copier" "SUCCESS"
else
    echo "Copier ya está instalado."
    log_status "Verificación de Copier" "SKIPPED"
fi

echo -e "\n=== Verificando carpeta 'app' ==="
if [ ! -d "app" ]; then
    echo "Creando carpeta 'app'..."
    mkdir -p app
    log_status "Creación de carpeta app" "SUCCESS"
    echo "Carpeta 'app' creada."
else
    echo "Carpeta 'app' ya existe."
    log_status "Verificación de carpeta app" "SKIPPED"
fi

echo -e "\n=== Verificando archivo YAML ==="
YAML_FILE="$(pwd)/copier-data-example.yml"
if [ ! -f "$YAML_FILE" ]; then
    echo "Error: Archivo YAML no encontrado en $YAML_FILE."
    log_status "Verificación de archivo YAML" "ERROR"
    exit 1
fi
echo "Archivo YAML encontrado: $YAML_FILE"
log_status "Verificación de archivo YAML" "SUCCESS"

echo -e "\n=== Ejecutando Copier con Doodba Template ==="
echo "Copiando plantilla Doodba..."
if copier copy gh:Tecnativa/doodba-copier-template ./app --trust --data-file "$YAML_FILE" --vcs-ref=HEAD --defaults --force; then
    log_status "Copia de plantilla Doodba" "SUCCESS"
    echo "Plantilla Doodba copiada correctamente."
else
    log_status "Copia de plantilla Doodba" "ERROR"
    echo "Error al copiar plantilla Doodba."
fi

echo -e "\n=== Cambiando al directorio 'app' ==="
cd app
log_status "Cambio a directorio app" "SUCCESS"

echo -e "\n=== Agregando usuario al grupo docker ==="
sudo usermod -aG docker $USER
log_status "Agregar usuario a grupo docker" "SUCCESS"
echo "Usuario agregado al grupo docker (requiere logout/login para aplicar)."

echo -e "\n=== Ejecutando comandos de configuración de Doodba ==="
# Asegurar que Docker Compose esté disponible para invoke
export DOCKER_COMPOSE_CMD="docker compose"

# Verificar si docker compose funciona, sino intentar docker-compose
if ! docker compose version &> /dev/null; then
    if command -v docker-compose &> /dev/null; then
        export DOCKER_COMPOSE_CMD="docker-compose"
    fi
fi

sg docker "/bin/bash -c '
cd $(pwd)
source $(dirname $(pwd))/venv/bin/activate
export DOCKER_COMPOSE_CMD=\"docker compose\"

# Verificar comando docker compose
if ! docker compose version &> /dev/null; then
    if command -v docker-compose &> /dev/null; then
        export DOCKER_COMPOSE_CMD=\"docker-compose\"
    fi
fi

echo \"Usando Docker Compose: \$DOCKER_COMPOSE_CMD\"

echo \"Ejecutando git-aggregate...\"
if invoke git-aggregate; then
    echo \"SUCCESS:git-aggregate\" > /tmp/doodba_status_git_aggregate
else
    echo \"ERROR:git-aggregate\" > /tmp/doodba_status_git_aggregate
fi

echo \"Ejecutando img-build...\"
if invoke img-build --pull; then
    echo \"SUCCESS:img-build\" > /tmp/doodba_status_img_build
else
    echo \"ERROR:img-build\" > /tmp/doodba_status_img_build
fi

echo \"Ejecutando start...\"
if invoke start; then
    echo \"SUCCESS:start\" > /tmp/doodba_status_start
else
    echo \"ERROR:start\" > /tmp/doodba_status_start
fi

echo \"Inicializando base de datos (con demo)...\"
if \$DOCKER_COMPOSE_CMD run --rm odoo --stop-after-init -i base; then
    echo \"SUCCESS:init-db-demo\" > /tmp/doodba_status_init_demo
else
    echo \"ERROR:init-db-demo\" > /tmp/doodba_status_init_demo
fi

echo \"Inicializando base de datos (sin demo)...\"
if \$DOCKER_COMPOSE_CMD run --rm odoo --without-demo=all --stop-after-init -i base; then
    echo \"SUCCESS:init-db-no-demo\" > /tmp/doodba_status_init_no_demo
else
    echo \"ERROR:init-db-no-demo\" > /tmp/doodba_status_init_no_demo
fi

echo \"Reiniciando servicios...\"
if invoke restart; then
    echo \"SUCCESS:restart\" > /tmp/doodba_status_restart
else
    echo \"ERROR:restart\" > /tmp/doodba_status_restart
fi
'"

# Leer estados de los comandos dentro de sg docker
for status_file in /tmp/doodba_status_*; do
    if [ -f "$status_file" ]; then
        status_content=$(cat "$status_file")
        IFS=':' read -r status_result command_name <<< "$status_content"
        
        case "$command_name" in
            "git-aggregate")
                log_status "Invoke: git-aggregate" "$status_result"
                ;;
            "img-build")
                log_status "Invoke: img-build" "$status_result"
                ;;
            "start")
                log_status "Invoke: start" "$status_result"
                ;;
            "init-db-demo")
                log_status "Inicialización DB (con demo)" "$status_result"
                ;;
            "init-db-no-demo")
                log_status "Inicialización DB (sin demo)" "$status_result"
                ;;
            "restart")
                log_status "Invoke: restart" "$status_result"
                ;;
        esac
        rm "$status_file"
    fi
done

echo -e "\n=== Proceso completado ==="
echo "Para aplicar los cambios del grupo docker, ejecuta: newgrp docker"
echo "O cierra sesión y vuelve a iniciar sesión."
echo -e "\nPara iniciar los servicios en el futuro:"
echo "  cd app"
echo "  docker compose up -d"

# Mostrar resumen final
show_summary
