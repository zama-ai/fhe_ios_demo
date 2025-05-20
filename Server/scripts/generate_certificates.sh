#!/bin/bash

set -x

# Ensure the script is run as root before attempting to regenerate certificates
if [ "$EUID" -ne 0 ]; then
    echo "Error: Root privileges required to generate SSL certificates."
    echo "Please re-run this script as root: 'sudo bash $0' or 'sudo make certificates'."
    exit 1
fi

# Change directory to the project root to ensure relative paths behave consistently
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(realpath "$SCRIPT_DIR/..")"
echo "From '$SCRIPT_DIR' to '$PROJECT_ROOT'"
cd "$PROJECT_ROOT"

# Load credentials
if [[ -f "secrets.env" ]]; then
    echo "Loading secrets..."
    set -o allexport
    source secrets.env
    set +o allexport
else
    echo "secrets.env not found"
fi

if [ "$USE_TLS" = "true" ]; then
    # Check for certbot
    if ! command -v certbot &> /dev/null; then
        echo "Certbot is not installed. Please install it and try again."
        echo "sudo apt-get update"
        echo "sudo apt install certbot"
        exit 1
    fi

    # Collect DOMAIN_NAME and CERTBOT_EMAIL if not set
    if [ -z "$DOMAIN_NAME" ]; then
        read -p "Enter your DOMAIN_NAME: " DOMAIN_NAME
    fi

    if [ -z "$CERTBOT_EMAIL" ]; then
        read -p "Enter your CERTBOT_EMAIL: " CERTBOT_EMAIL
    fi

    # Check if the ceriticqate already exists and delete it to avoid suffixes
    if certbot certificates | grep -q "Certificate Name: $DOMAIN_NAME"; then
        echo "Existing certificate '$DOMAIN_NAME' found. Deleting to avoid suffixes..."
        yes | certbot delete --cert-name "$DOMAIN_NAME"
    else
        echo "No existing certificate '$DOMAIN_NAME' found."
    fi

    certbot -v certonly --standalone \
        --non-interactive \
        --agree-tos \
        --email "$CERTBOT_EMAIL" \
        -d "$DOMAIN_NAME" \
        --cert-name "$DOMAIN_NAME"

    ls -altr /etc/letsencrypt/live/api.zama.ai/
    mkdir -p $HOST_CERTS_PATH
    cp $CERT_NAME/$CERT_FILE_NAME $HOST_CERTS_PATH/$CERT_FILE_NAME
    cp $CERT_NAME/$PRIVKEY_FILE_NAME $HOST_CERTS_PATH/$PRIVKEY_FILE_NAME
    chown $(logname):$(logname) $HOST_CERTS_PATH/*.pem
    chmod 644 $HOST_CERTS_PATH/*.pem
fi
