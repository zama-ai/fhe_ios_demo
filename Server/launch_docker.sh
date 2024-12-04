#!/bin/bash

# Set the image name
IMAGE_NAME="fhe_ios_demo_server"

# Set the Dockerfile name
DOCKERFILE_NAME="Dockerfile.server"

# Collect DOMAIN_NAME and CERTBOT_EMAIL
if [ -z "$DOMAIN_NAME" ]; then
    read -p "Enter your DOMAIN_NAME: " DOMAIN_NAME
fi

if [ -z "$CERTBOT_EMAIL" ]; then
    read -p "Enter your CERTBOT_EMAIL: " CERTBOT_EMAIL
fi

# Check for --force, --update, and --shell parameters
FORCE_REBUILD=false
UPDATE=false
SHELL_ONLY=false
for arg in "$@"; do
    if [[ "$arg" == "--force" ]]; then
        FORCE_REBUILD=true
    elif [[ "$arg" == "--update" ]]; then
        UPDATE=true
    elif [[ "$arg" == "--shell" ]]; then
        SHELL_ONLY=true
    fi
done

# Ensure the script is run as root (required for certbot)
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root to allow certificate generation."
    exit 1
fi

# Check if certificates exist on host
CERT_PATH="/etc/letsencrypt/live/$DOMAIN_NAME"
if [ ! -d "$CERT_PATH" ]; then
    echo "Certificates for $DOMAIN_NAME not found. Running certbot on the host to generate them."
    certbot certonly --standalone \
        --non-interactive \
        --agree-tos \
        --email "$CERTBOT_EMAIL" \
        -d "$DOMAIN_NAME" \
        --cert-name "$DOMAIN_NAME"
else
    echo "Certificates for $DOMAIN_NAME found."
fi

# Clean up existing containers...
echo "Cleaning up existing containers..."
# Get container IDs running the specified image or with the specific container name
CONTAINERS=$(docker ps -a -q --filter ancestor=$IMAGE_NAME --filter name=${IMAGE_NAME}_container)
if [ -n "$CONTAINERS" ]; then
    # Stop the containers
    echo "Stopping containers: $CONTAINERS"
    docker stop $CONTAINERS
    # Remove the containers
    echo "Removing containers: $CONTAINERS"
    docker rm $CONTAINERS
else
    echo "No containers to stop or remove."
fi

# Build the Docker image
if $FORCE_REBUILD; then
    echo "Force rebuilding Docker image using $DOCKERFILE_NAME..."
    docker build --no-cache -t $IMAGE_NAME -f $DOCKERFILE_NAME .
elif $UPDATE; then
    echo "Updating Docker image using $DOCKERFILE_NAME..."
    docker build -t $IMAGE_NAME -f $DOCKERFILE_NAME .
else
    echo "Using existing Docker image. Use --force to rebuild or --update to update files."
fi

# Run the Docker container based on mode
echo "Running Docker container..."
if $SHELL_ONLY; then
    echo "Starting container with shell access (entrypoint overridden)..."
    docker run -it \
        -p 80:80 \
        -p 443:5000 \
        -e DOMAIN_NAME="$DOMAIN_NAME" \
        --name ${IMAGE_NAME}_container \
        --entrypoint /bin/bash \
        -v /etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem:/project/cert.pem \
        -v /etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem:/project/key.pem \
        $IMAGE_NAME
else
    docker run -d \
        -p 80:80 \
        -p 443:5000 \
        -e DOMAIN_NAME="$DOMAIN_NAME" \
        --name ${IMAGE_NAME}_container \
        -v /etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem:/project/cert.pem \
        -v /etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem:/project/key.pem \
        $IMAGE_NAME
fi

# Show logs message only for detached mode
if ! $SHELL_ONLY; then
    echo "Container is running in detached mode. To view logs, use:"
    echo "docker logs -f ${IMAGE_NAME}_container"
fi