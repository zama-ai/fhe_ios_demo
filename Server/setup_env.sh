#!/bin/bash

if [ "$1" == "dev" ]; then
    echo "🚀 Testing in the development environment..."
    ENV_FILE=".env_dev"
elif [ "$1" == "staging" ]; then
    echo "🚀 Testing in the production environment..."
    ENV_FILE=".env_staging"
elif [ "$1" == "prod" ]; then
    echo "🚀 Testing in the production environment..."
    ENV_FILE=".env_prod"
else
    echo "Usage: $0 [mode=dev/prod/staging]"
    exit 1
fi 

# Load variables from '.env'
if [ -f $ENV_FILE ]; then
    set -o allexport  # Enables automatic export of variables
    source $ENV_FILE  # Loads the .env file
    set +o allexport  # Disables automatic export
else
    echo "Environment config file $ENV_FILE not found!"
    exit 1
fi
