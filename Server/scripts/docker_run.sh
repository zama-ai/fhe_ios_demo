#!/bin/bash

set -x

# Change directory to the project root to ensure relative paths behave consistently
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(realpath "$SCRIPT_DIR/..")"
echo "From '$SCRIPT_DIR' to '$PROJECT_ROOT'"
cd "$PROJECT_ROOT"

# Setup environment depending on the first argument
source setup_env.sh

# Load credentials
if [[ -f "secrets.env" ]]; then
    echo "Loading secrets..."
    set -o allexport
    source secrets.env
    set +o allexport
else
    echo "secrets.env not found"
    export USE_TLS="false"
fi

if [ "$USE_TLS" = "true" ]; then
    # Check for certbot
    if ! command -v certbot &> /dev/null; then
        echo "Certbot is not installed. Please install it and try again."
        echo "sudo apt-get update"
        echo "sudo apt install certbot"
        exit 1
    fi

    # Collect DOMAIN_NAME and CERTBOT_EMAIL if not set
    if [ -z "$DOMAIN_NAME" ]; then
        read -p "Enter your DOMAIN_NAME: " DOMAIN_NAME
    fi

    if [ -z "$CERTBOT_EMAIL" ]; then
        read -p "Enter your CERTBOT_EMAIL: " CERTBOT_EMAIL
    fi

    # Handle certificates
    if [ ! -d "$HOST_CERTS_PATH" ]; then
        echo "SSL Certificates for '$DOMAIN_NAME' not found in '$HOST_CERTS_PATH'. Running certbot..."

        # Ensure the script is run as root before attempting to regenerate certificates
        if [ "$EUID" -ne 0 ]; then
            echo "Error: Root privileges required to generate SSL certificates."
            echo "Please re-run this script as root: 'sudo bash $0'"
            exit 1
        fi
        
        certbot certonly --standalone \
            --non-interactive \
            --agree-tos \
            --email "$CERTBOT_EMAIL" \
            -d "$DOMAIN_NAME" \
            --cert-name "$DOMAIN_NAME"

        if [ $? -eq 0 ]; then
            echo "SSL certificates successfully generated for '$DOMAIN_NAME'."
        else
            echo "Error: Failed to generate SSL certificates."
            exit 1
        fi
    else
        echo "SSL Certificates for '$DOMAIN_NAME' already exist in '$HOST_CERTS_PATH'."
        ls -ltra $HOST_CERTS_PATH
    fi

    # Check permissions on the directory
    if [ ! -r "$HOST_CERTS_PATH" ] || [ ! -x "$HOST_CERTS_PATH" ]; then
        echo "Error: Insufficient permissions on '$HOST_CERTS_PATH'."
        echo "Try running:"
        echo "sudo chmod -R 755 $HOST_CERTS_PATH"
    fi
else 
    echo "🚀 Skipping certs volume (HTTP mode)"
    export HOST_CERTS_PATH="$(pwd)/dummy-certs"
    mkdir -p "$HOST_CERTS_PATH"
fi

echo "🚀 [$COMPOSE_PROJECT_NAME]: launching Docker containers using '$DOCKER_COMPOSE_NAME'..."
docker-compose -p "$COMPOSE_PROJECT_NAME" up -d --scale service_celery_usecases="$CELERY_WORKER_COUNT_USECASE_QUEUE"
    # --scale service_celery_ads="$CELERY_WORKER_COUNT_AD_QUEUE"

if [[ "$1" != "ci" ]]; then
  echo "[MODE=$1] Following logs..."
  docker-compose --env-file "$ENV_FILE" -f "$DOCKER_COMPOSE_NAME" -p "$COMPOSE_PROJECT_NAME" logs -f
else
  echo "[MODE=$1] Skipping logs - running in CI environment."
  docker-compose --env-file "$ENV_FILE" -f "$DOCKER_COMPOSE_NAME" -p "$COMPOSE_PROJECT_NAME" ps
fi
