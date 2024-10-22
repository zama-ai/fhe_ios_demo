#!/bin/bash

# Set the image name
IMAGE_NAME="fhe_appstore_server"

# Clean up existing containers and images
echo "Cleaning up existing containers and images..."
docker stop $(docker ps -a -q --filter ancestor=$IMAGE_NAME) 2>/dev/null
docker rm $(docker ps -a -q --filter ancestor=$IMAGE_NAME) 2>/dev/null
docker rmi $IMAGE_NAME 2>/dev/null

# Build the Docker image
echo "Building Docker image..."
docker build -t $IMAGE_NAME -f Dockerfile.server .

# Check if the build was successful
if [ $? -eq 0 ]; then
    echo "Docker image built successfully."
    
    # Run the Docker container
    echo "Running Docker container..."
    docker run -p 5000:5000 $IMAGE_NAME
else
    echo "Error: Docker image build failed."
    exit 1
fi