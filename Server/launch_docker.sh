#!/bin/bash

# Setup environment depending on the first argument
source setup_env.sh

# Load credentials
if [[ -f "secrets.env" ]]; then
    echo "Loading secrets..."
    set -o allexport
    source secrets.env
    set +o allexport
else
    exit 1
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
    fi

    # Check permissions on the directory
    if [ ! -r "$HOST_CERTS_PATH" ] || [ ! -x "$HOST_CERTS_PATH" ]; then
        echo "Error: Insufficient permissions on '$HOST_CERTS_PATH'."
        echo "Try running:"
        echo "sudo chmod -R 755 $HOST_CERTS_PATH"
    fi
fi

# Ensure necessary directories exist on the host before launching Docker
for dir in "$SHARED_DIR" "$BACKUP_DIR"; do
    mkdir -p "$dir"
    chmod -R 777 "$dir"
    echo "Set correct permissions to '$dir' directory."
done

docker-compose -p "$COMPOSE_PROJECT_NAME" up -d --scale service_celery_usecases="$CELERY_WORKER_COUNT_USECASE_QUEUE"
    # --scale service_celery_ads="$CELERY_WORKER_COUNT_AD_QUEUE"

docker-compose --env-file "$ENV_FILE" -f "$DOCKER_COMPOSE_NAME" -p "$COMPOSE_PROJECT_NAME" logs -f
