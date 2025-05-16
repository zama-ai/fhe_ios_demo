#!/bin/bash

# Deployment Script for fhe_ios_demo Server

# Change directory to the project root to ensure relative paths behave consistently
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(realpath "$SCRIPT_DIR/..")"
echo "From '$SCRIPT_DIR' to '$PROJECT_ROOT'"
cd "$PROJECT_ROOT"

# Setup environment depending on the first argument
source setup_env.sh

# Parse command line arguments
REBUILD_RUST=false
NO_CACHE=false

# Shift to ignore the first argument (handled by setup_env.sh)
shift

for arg in "$@"; do
    case "$arg" in
        --rebuild-rust)
            REBUILD_RUST=true
            ;;
        --no-cache)
            NO_CACHE=true
            ;;
        *)
            echo "Usage : $0 [dev|staging|prod|ci] [--no-cache] [--rebuild-rust]"
            exit 1
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
echo "🧹 Cleaning up existing containers..."
# With `docker-compose down,` Docker Compose tries to delete the network associated with 
# the services. If no network exists, it displays this warning: 
# `WARNING: Network server_default not found.`
if [[ $NO_CACHE == true ]]; then
    echo "WARNING: Cache is disabled! Performing a full cleanup..."
    docker-compose -p "$COMPOSE_PROJECT_NAME" down --rmi all
    docker system prune -a -f
else
    echo "WARNING: Cache is enabled! Performing a standard cleanup..."
    docker-compose -p "$COMPOSE_PROJECT_NAME" down
fi

# Build the Rust stage if needed
if [[ $REBUILD_RUST == true ]]; then
    echo "🔨 Building Rust stage..."
    docker build --platform linux/amd64 --target rust-builder -t "$RUST_IMAGE_NAME" -f "$DOCKERFILE_NAME" .
fi

# # Build the Docker image and starting the Docker containers
echo "🔨 [$COMPOSE_PROJECT_NAME]: building the image '$FINAL_IMAGE_NAME'..."
if [[ $NO_CACHE == true ]]; then
    echo "WARNING: Cache is disabled. Performing a full rebuild of the image $FINAL_IMAGE_NAME'..."
    docker build --platform linux/amd64 -t "$FINAL_IMAGE_NAME:latest" -f "$DOCKERFILE_NAME" "$DOCKERFILE_LOCATION" --no-cache
else
    echo "WARNING: Cache is enabled. Building the image $FINAL_IMAGE_NAME' using available cached layers..."
    docker build --platform linux/amd64 -t "$FINAL_IMAGE_NAME:latest" -f "$DOCKERFILE_NAME" "$DOCKERFILE_LOCATION"
fi
