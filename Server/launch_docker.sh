#!/bin/bash

# Deployment Script for fhe_ios_demo Server

# Set the image names
RUST_IMAGE_NAME="fhe_ios_demo_rust_builder"
FINAL_IMAGE_NAME="fhe_ios_demo_server"

# Parse command line arguments
REBUILD_RUST=false

# Load environment variables
if [ -f .env ]; then
    set -o allexport  # Enables automatic export of variables
    source .env       # Loads the .env file
    set +o allexport  # Disables automatic export
fi

for arg in "$@"; do
    case "$arg" in
        --rebuild-rust)
            REBUILD_RUST=true
            ;;
    esac
done

# Check for certbot
if ! command -v certbot &> /dev/null; then
    echo "Certbot is not installed. Please install it and try again."
    exit 1
fi

for arg in "$@"; do
    case "$arg" in
        --rebuild-rust)
            REBUILD_RUST=true
            ;;
    esac
done

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

# Clean up existing containers
echo "Cleaning up existing containers..."
# With `docker-compose down,` Docker Compose tries to delete the network associated with 
# the services. If no network exists, it displays this warning: 
# `WARNING: Network server_default not found.`
docker-compose down --rmi all

# Build the Rust stage if needed
if $REBUILD_RUST; then
    echo "Building Rust stage..."
    docker build --target rust-builder -t $RUST_IMAGE_NAME -f $DOCKERFILE_NAME .
fi

# Build the Docker image and starting the Docker containers
echo "Building the image '$FINAL_IMAGE_NAME' and starting the Docker containers using '$DOCKER_COMPOSE_FILENAME'..."
docker-compose build --no-cache
docker-compose up -d --scale service_celery=$CELERY_NB_INSTANCE

echo "--------------"
echo "Containers are running in detached mode. To view real-time logs, use: 'docker-compose logs -f'"
echo "Check the container: 'docker exec -it container_fastapi_app /bin/bash"
echo ""
echo "Check the status of all running containers: 'docker-compose ps'"
echo ""
echo "Celery worker monitoring:"
echo "View active tasks currently being processed by Celery: 'docker exec -it server_service_celery_1 celery -A server.celery_app inspect active'"
echo "View all registered tasks available in Celery: 'docker exec -it server_service_celery_1 celery -A server.celery_app inspect registered'"
echo ""
echo "View queued taks in Redis: 'docker exec -it container_redis_bd redis-cli LRANGE celery 0 -1'"
echo "Refresh Redis 'docker exec -it container_redis_bd redis-cli FLUSHALL'"
echo ""
echo "Verifying task recovery after a container crash:"
echo """
- Step 1: Open Terminal (1) and launch tasks using: 'bash ./client.curl'
- Step 2: Open Terminal (2) list running containers with: 'docker ps', then monitor logs of a Celery worker: 'docker logs -f server_service_celery_1docker logs -f server_service_celery_1'
- Step 3: Open Terminal (3), simulate a crash by repeatedly killing the Celery process inside the container: 
    'for i in {1..1000}; do docker exec server_service_celery_2 pkill -9 -f 'celery'; done'
- Step 4: Return to Terminal (1) and check logs. The tasks handled by the killed container should transition from 'started' back to 'queued', awaiting reassignment.
"""
