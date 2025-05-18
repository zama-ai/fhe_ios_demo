#!/bin/bash

set -x

# Change directory to the project root to ensure relative paths behave consistently
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(realpath "$SCRIPT_DIR/..")"
echo "From '$SCRIPT_DIR' to '$PROJECT_ROOT'"
cd "$PROJECT_ROOT"

# Setup environment depending on the first argument
source setup_env.sh

# Load credentials
if [[ -f "secrets.env" ]]; then
    echo "Loading secrets..."
    set -o allexport
    source secrets.env
    set +o allexport
else
    echo "secrets.env not found"
    export USE_TLS="false"
fi

echo "🚀 [$COMPOSE_PROJECT_NAME]: launching Docker containers using '$DOCKER_COMPOSE_NAME'..."
docker-compose -p "$COMPOSE_PROJECT_NAME" up -d --scale service_celery_usecases="$CELERY_WORKER_COUNT_USECASE_QUEUE"
    --scale service_celery_ads="$CELERY_WORKER_COUNT_AD_QUEUE"

if [[ "$1" != "ci" ]]; then
  echo "[MODE=$1] Following logs..."
  docker-compose --env-file "$ENV_FILE" -f "$DOCKER_COMPOSE_NAME" -p "$COMPOSE_PROJECT_NAME" logs -f
else
  echo "[MODE=$1] Skipping logs - running in CI environment."
  docker-compose --env-file "$ENV_FILE" -f "$DOCKER_COMPOSE_NAME" -p "$COMPOSE_PROJECT_NAME" ps
fi
