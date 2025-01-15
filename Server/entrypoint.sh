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
  exec celery -A server.celery_app worker --loglevel=info
else
  echo "🚀 Starting Uvicorn Python server..."
  exec python server.py
fi
