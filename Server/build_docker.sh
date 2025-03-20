#!/bin/bash

# Deployment Script for fhe_ios_demo Server

# Parse command line arguments
REBUILD_RUST=false

# Setup environment depending on the first argument
source .common_env

for arg in "$@"; do
    case "$arg" in
        --rebuild-rust)
            REBUILD_RUST=true
            ;;
    esac
done

# Check for docker-compose
if ! command -v docker-compose &> /dev/null; then
    echo "docker-compose is not installed. Please install it and try again."
    echo "sudo apt update"
    echo "sudo apt install docker-compose"
    exit 1
fi

# Clean up existing containers
#echo "Cleaning up existing containers..."
# With `docker-compose down,` Docker Compose tries to delete the network associated with 
# the services. If no network exists, it displays this warning: 
# `WARNING: Network server_default not found.`
#docker-compose -p "$COMPOSE_PROJECT_NAME" down --rmi all
#docker system prune -a -f

# Build the Rust stage if needed
if $REBUILD_RUST; then
    echo "Building Rust stage..."
    docker build --target rust-builder -t "$RUST_IMAGE_NAME" -f "$DOCKERFILE_NAME" .
fi

# Build the Docker image and starting the Docker containers
echo "In $COMPOSE_PROJECT_NAME: building the image '$FINAL_IMAGE_NAME' and starting the Docker containers using '$DOCKER_COMPOSE_NAME'..."
docker build -t "$FINAL_IMAGE_NAME:latest" -f "$DOCKERFILE_NAME" "$DOCKERFILE_LOCATION"