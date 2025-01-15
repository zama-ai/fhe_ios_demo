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
docker-compose down

# Build the Rust stage if needed
if $REBUILD_RUST; then
    echo "Building Rust stage..."
    docker build --target rust-builder -t $RUST_IMAGE_NAME -f $DOCKERFILE_NAME .
fi

# Build the Docker image and starting the Docker containers
echo "Building the image '$FINAL_IMAGE_NAME' and starting the Docker containers using '$DOCKER_COMPOSE_FILENAME'..."
docker-compose up --build -d

echo "Containers are running in detached mode. To view logs, use:"
echo "docker-compose logs -f"
