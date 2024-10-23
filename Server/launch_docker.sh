#!/bin/bash

# Set the image name
IMAGE_NAME="fhe_appstore_server"

# Set the Dockerfile name
DOCKERFILE_NAME="Dockerfile.server"

# Check for --force and --update parameters
FORCE_REBUILD=false
UPDATE=false
if [[ "$1" == "--force" ]]; then
    FORCE_REBUILD=true
elif [[ "$1" == "--update" ]]; then
    UPDATE=true
fi

# Clean up existing containers
echo "Cleaning up existing containers..."

# Get container IDs running the specified image
CONTAINERS=$(docker ps -a -q --filter ancestor=$IMAGE_NAME)

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

# Run the Docker container in detached mode
echo "Running Docker container..."
docker run -d -p 80:5000 --name ${IMAGE_NAME}_container $IMAGE_NAME

# Optional: Display container logs
echo "Container is running in detached mode. To view logs, use:"
echo "  docker logs -f ${IMAGE_NAME}_container"
