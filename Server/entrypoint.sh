#!/bin/bash

# Check that the certificates exist
if [ ! -f "/project/cert.pem" ] || [ ! -f "/project/key.pem" ]; then
    echo "Error: Certificates not found in /project/. Please ensure cert.pem and key.pem are available."
    exit 1
fi

# Start the Python server
exec python server.py