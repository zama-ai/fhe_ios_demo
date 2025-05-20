# 🔐 Fully Homomorphic Encryption (FHE) Application Server

This repository showcases an application server powered by Fully Homomorphic Encryption (FHE). It provides a simple API to securely process encrypted client data, perform computations on the server side without ever decrypting the data, and return encrypted results that only the client can decrypt.

# Use-cases:
### 1. **Sleep Analysis:**

Users can upload recordings of their sleep (e.g., data collected from an Apple Watch). The data is encrypted locally before being sent to the server.

The server then analyzes the encrypted sleep data based on medical expertise, such as the Pittsburgh Sleep Quality Index (PSQI), represents a set of rules to evaluate the quality of sleep for a given night. being structured  as a series of nights, each composed of several cycles, themselves divided into multiple stages. PSQI returns an encrypted sleep quality score from 1 (excellent) to 5 (poor). The structure follows:

Sleep data is structured After applying a set of rules, the server returns a score from 1 (excellent) to 5 (poor) — still encrypted — which only the user can decrypt.

### 2. **Weight Statistics:**

Users can input their weight through the application. As with all use-cases, the data is encrypted before being sent to the server.

The server performs statistical analysis over the encrypted list of inputs and returns results such as maximum, minimum, and average weight.

### 3. **Ad Targeting:**

Users can share their information about their interests or behavior. The server processes this encrypted input and returns tailered ads, without ever accessing the raw data.

## Application Architecture

- _FastAPI_ is used with _Uvicorn_ as the ASGI server to expose HTTP endpoints

- _Celery_ handles task execution in a asynchronous, and non-blocking manner, allowing heavy computations to run in the background without blocking the API.

- _Redis_ acts as both the message broker and result backend for _Celery_. It queues tasks and temporarily stores results with a configurable time-to-live.

## API endpoints
The following endpoints are available for interacting with the server:

Endpoint	          |      Description
--------------------|----------------------------------------
/add_key      	     | Uploads the client's public evaluation key so the server can process the encrypted input.
/get_use_cases	     | Lists the available FHE use-cases (e.g., sleep analysis, weight stats).
/start_task	     | Starts a computation for a given use-case along with the encrypted input.
/get_task_status    | Returns the current status of a task (started, queued, success, completed, revoked, unknown).
/get_task_result    | Retrieves the encrypted result of the task.
/cancel_task	     | Cancels a running task if necessary.
/list_current_tasks | Lists all currently running tasks on the server.


## Setting up the Server (for local usage)

The application is designed to run in three environments:

- _dev_ (local development)
- _staging_ (pre-production testing)
- _prod_ (production deployment)

### Local development (dev environment)

This environment is ideal for users who want to run the server locally for development and testing. No SSL or authentication is required.

#### 1. Prerequisites

To run this project, make sure you have the following installed on your machine:

- Install [docker-compose](https://pypi.org/project/docker-compose/) (to handle multiple servercie)
- Install Python version 3.10 or higher.

#### 2. Clone and set up the project

```bash
git clone https://<USERNAME>:<TOKEN>@github.com/zama-ai/fhe_ios_demo.git
cd fhe_ios_demo/Server/
python -m venv .venv
source .venv/bin/activate
```

#### 3. Build and run the docker image

By default, Docker launches in local (dev) mode, and all API calls will go through localhost.

Although the production domain _https://api.zama.ai_ exists, it requires a secure SSL connection and cannot be used without proper credentials.

```bash
make docker_build
make docker_run  # By default ENV=dev
```

This launches the three main services, use `docker ps` to ensure all services are up and running:

- Redis (for task queuing)
- Celery (for background processing)
- Uvicorn (to serve the API)

Example of active containers:

```bash
dev_fhe_ios_demo_service_celery_usecases_1
dev_fhe_ios_demo_service_celery_usecases_2
dev_container_fastapi_app
dev_container_redis_bd
```

4. Run tests (optional)

```bash
make tests_build
make test_run
```

## Testing the API locally with `curl`

You can interact with the server manually using curl, example: `curl -X GET http://localhost:82/get_use_cases`

To generate test keys and encrypted inputs, you can run:

```bash
source .venv/bin/activate
pytest test_<task_name>.py
```
This will create the necessary files in the `project/uploaded_files` directory.


**Example curl usage:**

```bash

URL=http://localhost:82

RESPONSE=$(curl -X POST "$URL/add_key" \
               -F "key=$SERVER_KEY" \
               -F "task_name=$TASK_NAME")

UID=$(echo "$response" | jq -r '.uid')

RESPONSE=$(curl -s -X POST "$URL/start_task" \
     -F "uid=$EXTRACTED_UID" \
     -F "task_name=$TASK_NAME" \
     -F "encrypted_input=$ENCRYPTED_INPUT")

TASK_ID=$(echo "$RESPONSE" | jq -r '.task_id')

curl -s -X GET "$URL/get_task_status?task_id=$TASK_IDS&uid=$UID"
```

## Inspect Celery and Redis

View active tasks currently being processed by Celery:

```bash
docker exec -it dev_fhe_ios_demo_service_celery_usecases_1 celery -A server.celery_app inspect active
```

View queued tasks in Redis:

```bash
docker exec -it dev_container_redis_bd redis-cli LRANGE usecases 0 -1
```

Check the containers:

```bash
docker exec -it dev_container_fastapi_app /bin/bash

docker exec -it dev_fhe_ios_demo_service_celery_usecases_1 /bin/bash
```

## Performance Summary

<!-- BENCHMARK_TABLE_START -->
Task | Device | Server time (avg ± std) | E2E time (avg ± std) | Server time range (s) | E2E time range (s)
-----|--------|-------------------------|----------------------|-----------------------|----------------------
ad_targeting | cpu | 4.26 ± 0.61 s | 20.19 ± 0.13 s | 3.91 - 5.63 | 20.02 - 20.42
ad_targeting | cuda | 1.13 ± 0.02 s | 11.63 ± 0.06 s | 1.12 - 1.16 | 11.53 - 11.76
sleep_quality | cpu | 52.06 ± 12.63 s | 84.38 ± 7.17 s | 20.82 - 57.11 | 81.20 - 101.77
sleep_quality | cuda | 44.54 ± 11.77 s | 74.40 ± 0.68 s | 19.81 - 50.43 | 72.60 - 74.69
weight_stats | cpu | 3.60 ± 0.01 s | 18.98 ± 0.08 s | 3.59 - 3.62 | 18.84 - 19.05
weight_stats | cuda | 3.33 ± 0.04 s | 6.67 ± 0.02 s | 3.27 - 3.40 | 6.64 - 6.70
<!-- BENCHMARK_TABLE_END -->

Notes:

- Server time corresponds to the pure FHE compute time on the server, excluding any network or client-side operations.

- End-to-End (E2E) time includes the full processing pipeline: client-side encryption, data transfer to the server, FHE computation, and the transfer of the encrypted result back to the client.

- All benchmarks were conducted on an AWS c5.4xlarge instance (16 vCPUs, 32 GiB RAM) and g4dn.8xlarge instance (32 vCPUs, 1 NVIDIA T4 GPU, 128 GiB RAM).

- Only the _ad_targeting_ use-case currently benefits from CUDA acceleration. GPU optimization for the remaining use-cases is planned in upcoming releases.