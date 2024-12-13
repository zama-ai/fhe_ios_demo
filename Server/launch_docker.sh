#!/bin/bash

# Set the image names
RUST_IMAGE_NAME="fhe_ios_demo_rust_builder"
FINAL_IMAGE_NAME="fhe_ios_demo_server"

# Set the Dockerfile name
DOCKERFILE_NAME="Dockerfile.server"

# Parse command line arguments
REBUILD_RUST=false

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

# Check for certbot
if ! command -v certbot &> /dev/null; then
    echo "Certbot is not installed. Please install it and try again."
    exit 1
fi

# Ensure root privileges
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root to allow certificate generation."
    exit 1
fi

# Handle certificates
CERT_PATH="/etc/letsencrypt/live/$DOMAIN_NAME"
if [ ! -d "$CERT_PATH" ]; then
    echo "Certificates for $DOMAIN_NAME not found. Running certbot..."
    certbot certonly --standalone \
        --non-interactive \
        --agree-tos \
        --email "$CERTBOT_EMAIL" \
        -d "$DOMAIN_NAME" \
        --cert-name "$DOMAIN_NAME"
else
    echo "Certificates for $DOMAIN_NAME found."
fi

# Clean up existing containers
echo "Cleaning up existing containers..."
CONTAINERS=$(docker ps -a -q --filter ancestor=$FINAL_IMAGE_NAME --filter name=${FINAL_IMAGE_NAME}_container)
if [ -n "$CONTAINERS" ]; then
    echo "Stopping containers: $CONTAINERS"
    docker stop $CONTAINERS
    echo "Removing containers: $CONTAINERS"
    docker rm $CONTAINERS
else
    echo "No containers to stop or remove."
fi

# Build the Rust stage if needed
if $REBUILD_RUST; then
    echo "Building Rust stage..."
    docker build --target rust-builder -t $RUST_IMAGE_NAME -f $DOCKERFILE_NAME .
fi

# Build the final image (default behavior is to rebuild without Rust)
echo "Building Docker image..."
docker build -t $FINAL_IMAGE_NAME -f $DOCKERFILE_NAME .

# Run the container
echo "Running Docker container..."
docker run -d \
    -p 80:80 \
    -p 443:5000 \
    -e DOMAIN_NAME="$DOMAIN_NAME" \
    --name ${FINAL_IMAGE_NAME}_container \
    -v /etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem:/project/cert.pem \
    -v /etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem:/project/key.pem \
    $FINAL_IMAGE_NAME

echo "Container is running in detached mode. To view logs, use:"
echo "docker logs -f ${FINAL_IMAGE_NAME}_container"