#!/bin/bash

if [[ "$1" == "dev" || "$1" == "ci" ]]; then
    echo "🚀 Testing in the development environment..."
    export ENV_FILE=".env_dev"
elif [ "$1" == "staging" ]; then
    echo "🚀 Testing in the staging environment..."
    export ENV_FILE=".env_staging"
elif [ "$1" == "prod" ]; then
    echo "🚀 Testing in the production environment..."
    export ENV_FILE=".env_prod"
else
    echo "Usage: $0 [dev|staging|prod|ci]"
    exit 1
fi 

# Load variables from '.env'
if [ -f $ENV_FILE ]; then
    set -o allexport  # Enables automatic export of variables
    source .common_env # Load common env variables
    source $ENV_FILE  # Loads the .env file
    set +o allexport  # Disables automatic export
else
    echo "Environment config file $ENV_FILE not found!"
    exit 1
fi

# Ensure necessary directories exist on the host before launching Docker
for dir in "$SHARED_DIR" "$BACKUP_DIR"; do
    mkdir -p "$dir"
    chmod -R 777 "$dir"
    echo "Set correct permissions to '$dir' directory."
done
