# Setting a server and a client (WIP)

FIXME:
- on the server side, add the Rust code which:
    - use the evaluation key
    - read an encrypted input
    - do a small FHE computation, eg f(x) = x + 42
    - save the encrypted output
- compile this to a binary, and call it in the commandline of server.py
- certainly add this binary in the Dockerfile.server
- check it works fine

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
python deploy_to_docker.py
```

You should see:

```
INFO:     Started server process [8]
INFO:     Waiting for application startup.
INFO:     Application startup complete.
INFO:     Uvicorn running on http://0.0.0.0:5000 (Press CTRL+C to quit)
```

Here, you server is running and ready to serve, on port 8888.

## On the client side with Python

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

## On the client side with Swift

2. Run the swift script

```shell
swift client.swift
```
