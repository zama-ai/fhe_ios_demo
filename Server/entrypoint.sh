#!/bin/bash
set -x # Debug mode
 
# Check that the certificates exist
if [ ! -e "$CONTAINER_CERTS_PATH/$CERT_FILE_NAME" ] || [ ! -e "$CONTAINER_CERTS_PATH/$PRIVKEY_FILE_NAME" ]; then
    echo "Checking certificates in $CONTAINER_CERTS_PATH :"
    ls -l "$CONTAINER_CERTS_PATH/" || echo "Directory '$CONTAINER_CERTS_PATH' not found."

    cert_path=$(realpath "$CONTAINER_CERTS_PATH/$CERT_FILE_NAME" 2>/dev/null || echo "'$CERT_FILE_NAME' not found!")
    key_path=$(realpath "$CONTAINER_CERTS_PATH/$PRIVKEY_FILE_NAME" 2>/dev/null || echo "'$PRIVKEY_FILE_NAME' not found!")

    echo "Error: Certificates not found in '$CONTAINER_CERTS_PATH'. Please ensure '$CERT_FILE_NAME' and '$PRIVKEY_FILE_NAME' are available."
    exit 1
fi

# Start the appropriate service
if [ "$RUN_TYPE" = "usecases" ]; then
  echo "🚀 Starting Celery Worker for tasks..."
  exec celery -A tasks.celery_app worker \
      --loglevel="$CELERY_LOGLEVEL" \
      --queues="usecases" \
      --concurrency="$CELERY_WORKER_CONCURRENCY_USECASE_QUEUE"
elif [ "$RUN_TYPE" = "fastapi" ]; then
    if [ -f "$CONTAINER_CERTS_PATH/$PRIVKEY_FILE_NAME" ] && [ -f "$CONTAINER_CERTS_PATH/$CERT_FILE_NAME" ]; then
      export PORT=$FASTAPI_CONTAINER_PORT_HTTPS
      echo "🚀 Starting Uvicorn Python server in HTTPS mode...POST:$PORT"
      exec uvicorn server:app \
          --host 0.0.0.0 \
          --port "$PORT" \
          --ssl-keyfile "$CONTAINER_CERTS_PATH/$PRIVKEY_FILE_NAME" \
          --ssl-certfile "$CONTAINER_CERTS_PATH/$CERT_FILE_NAME"
    else
      export PORT=$FASTAPI_CONTAINER_PORT_HTTP
      echo "🚀 Starting Uvicorn Python server in HTTP mode...POST:$PORT"
      exec uvicorn server:app \
          --host 0.0.0.0 \
          --port "$PORT"
    fi
elif [ "$RUN_TYPE" = "ads" ]; then
  echo "🚀 Starting Celery Worker for ads..."
  exec celery -A tasks.celery_app worker \
        --loglevel="$CELERY_LOGLEVEL" \
        --queues="ads" \
        --concurrency="$CELERY_WORKER_CONCURRENCY_AD_QUEUE"
else
  echo "RUN_TYPE='$RUN_TYPE' not valid!"
fi
