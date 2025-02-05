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
if [ "$RUN_CELERY" = "true" ]; then
  echo "🚀 Starting Celery Worker..."
  # Running Celery as root is not a best practice and triggers a security warning.
  # Setting `user: "nobody:nogroup"` would eliminate the warning, but it prevents Celery from
  # accessing necessary files, which is required in our use-case.
  # -A tasks.celery_app: Indicates where the celery app is defined
  # --loglevel=debug   : Displays all the information
  exec celery -A tasks.celery_app worker \
      --loglevel="$CELERY_LOGLEVEL" \
      --queues="use-cases" \
      --concurrency="$CELERY_CONCURRENCY" \

else
  echo "🚀 Starting Uvicorn Python server..."
  exec uvicorn server:app \
      --host 0.0.0.0 \
      --port "$CONTAINER_PORT" \
      --ssl-keyfile "$CONTAINER_CERTS_PATH/$PRIVKEY_FILE_NAME" \
      --ssl-certfile "$CONTAINER_CERTS_PATH/$CERT_FILE_NAME"
fi
