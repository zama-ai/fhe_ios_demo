# Setting a server and a client (WIP)

Python, Swift and cURL clients are working.
- Tip #1: To upload locally generated serverKey and encrypted input, look at Xcode Console for the path to these files.
- Tip #2: To decrypt the server-generated output, drop it in the shared iOS folder mentioned above.

## Running the server

1. Set your Python environment

```
python3.10 -m venv .venv
source .venv/bin/activate
```
(use `python3` instead of `python3.10` if you don't have 3.10 installed')

2. Instal Docker 
```
https://docs.docker.com/desktop/install/mac-install/
```

3. Clean docker

```
docker rm -f $(docker ps -a -q)
```

4. Run the server

```
./launch_docker.sh
```

You should see:

```
INFO:     Started server process [8]
INFO:     Waiting for application startup.
INFO:     Application startup complete.
INFO:     Uvicorn running on http://0.0.0.0:5000 (Press CTRL+C to quit)
```

Here, you server is running and ready to serve, on port 8888.

## Test client side with curl

Run one of the two API calls (/add_key and /compute) found in client.curl


## Test client side with Swift

```shell
swift client.swift
```

## Test client side with Python

1. Set your Python environment

```
python3.10 -m venv .venvclient
source .venvclient/bin/activate
pip install -r client_requirements.txt
```
(use `python3` instead of `python3.10` if you don't have 3.10 installed')

2. Run the client

```
URL="http://localhost:8888" python client.py
```

