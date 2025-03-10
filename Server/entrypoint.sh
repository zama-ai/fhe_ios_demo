#!/bin/bash
set -x # Debug mode

# Start the appropriate service based on RUN_TYPE
case "$RUN_TYPE" in
    fastapi)
        if [ "$USE_TLS" = "true" ]; then
            # Check if the certificates exist
            if [ ! -e "$CONTAINER_CERTS_PATH/$CERT_FILE_NAME" ] || [ ! -e "$CONTAINER_CERTS_PATH/$PRIVKEY_FILE_NAME" ]; then
                echo "Error: Certificates not found in '$CONTAINER_CERTS_PATH'."
                echo "Please ensure '$CERT_FILE_NAME' and '$PRIVKEY_FILE_NAME' are available."
                exit 1
            fi

            # Start FastAPI in HTTPS mode
            export PORT=$FASTAPI_CONTAINER_PORT_HTTPS
            echo "🚀 Starting Uvicorn Python server in HTTPS mode... PORT:$PORT"
            exec uvicorn server:app \
                --host 0.0.0.0 \
                --port "$PORT" \
                --ssl-keyfile "$CONTAINER_CERTS_PATH/$PRIVKEY_FILE_NAME" \
                --ssl-certfile "$CONTAINER_CERTS_PATH/$CERT_FILE_NAME"
        else
            # Start FastAPI in HTTP mode
            export PORT=$FASTAPI_CONTAINER_PORT_HTTP
            echo "⚠️ Warning: Starting FastAPI in HTTP mode; this mode should only be used in a development environment."
            echo "🚀 Starting Uvicorn Python server in HTTP mode... PORT:$PORT"
            exec uvicorn server:app --host 0.0.0.0 --port "$PORT"
        fi
        ;;

    usecases)
        # Start Celery worker for usecases queue
        echo "🚀 Starting Celery Worker for tasks..."
        exec celery -A tasks.celery_app worker \
            --loglevel="$CELERY_LOGLEVEL" \
            --queues="usecases" \
            --concurrency="$CELERY_WORKER_CONCURRENCY_USECASE_QUEUE"
        ;;

    ads)
        # Start Celery worker for ads queue
        echo "🚀 Starting Celery Worker for ads..."
        exec celery -A tasks.celery_app worker \
            --loglevel="$CELERY_LOGLEVEL" \
            --queues="ads" \
            --concurrency="$CELERY_WORKER_CONCURRENCY_AD_QUEUE"
        ;;

    *)
        # Invalid RUN_TYPE
        echo "RUN_TYPE='$RUN_TYPE' is not valid!"
        exit 1
        ;;
esac
