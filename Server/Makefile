include .common_env
export

VENV_DIR=.venv_test

# make <cible> VAR1=valeur1 VAR2=valeur2 ...

# Pytest flags
test_flags ?= -vvs
# Target environment (dev, staging, prod, ci)        
environment ?= dev
# Which environment variables to set
ENV_FILE = $(if $(filter ci,$(environment)),.env_dev,.env_$(environment))
# Defines the name prefix used by docker-compose for containers
# depending on the current environment (e.g., dev, staging, prod, ci)
PREFIX = $(if $(filter ci,$(environment)),dev_fhe_ios_demo,$(environment)_fhe_ios_demo)
# Docker build cache option. Use '' to enable cache or '--no-cache' to disable it        
cache ?=
# Force Rust rebuild. Use '' to enable cache or '--rebuild_rust' to disable it      
rebuild_rust ?=
# Compute device used for execution (cpu or gpu)
device ?= cpu
# Output CSV file for benchmark results
CSV_FILE := benchmark.csv
# Current date
DATE := $(shell date "+%Y-%m-%d")
# List of benchmarked tasks
TASKS := ad_targeting weight_stats sleep_quality
# Instance type (e.g., c5.4xlarge or g4dn.8xlarge)
machine ?= c5.4xlarge
# Tests
TESTS = ad_targeting weight_stats sleep_quality endpoints

.PHONY: check_certificates certificates
.PHONY: docker_build docker_run docker_build_run
.PHONY: tests_build tests_run
.PHONY: clean_files benchmark

docker_build: check_certificates
	bash ./scripts/docker_build.sh $(environment) $(cache) $(rebuild_rust)

docker_run:
	@if [ $$(docker images | grep $$FINAL_IMAGE_NAME | wc -l) -eq 0 ]; then \
		echo "❌ The docker image '$$FINAL_IMAGE_NAME' does not exist."; \
		echo "Please run: 'make docker_build' first!"; \
		exit 1; \
	fi
	bash ./scripts/docker_run.sh $(environment)

docker_build_run: check_certificates
	bash ./scripts/docker_build.sh $(environment) $(cache) $(rebuild_rust)
	bash ./scripts/docker_run.sh $(environment)

tests_build:
	@echo "🔧 Building test environment for '$(environment)' using '$(ENV_FILE)' variables..."
	@bash -c 'set -a && source $(ENV_FILE) && VENV_DIR=$(VENV_DIR) && set +a && bash ./scripts/tests_build.sh'
	@echo "🔨 Building Rust components in Docker..."
	@docker run --platform linux/amd64 \
		-v $(PWD):/app \
		-w /app \
		--rm \
		rust:1.84 \
		bash -c 'cd tasks/weight_stats && RUSTFLAGS="-C target-feature=+aes,+rdseed" cargo build --release && cd ../sleep_quality && RUSTFLAGS="-C target-feature=+aes,+rdseed" cargo build --release'
	@echo "📦 Installing Python packages..."
	@bash -c 'source $(VENV_DIR)/bin/activate && maturin develop --release --manifest-path tasks/weight_stats/Cargo.toml && maturin develop --release --manifest-path tasks/sleep_quality/Cargo.toml'

tests_run:
	@if [ ! -d "$(VENV_DIR)" ]; then \
		echo "❌ Virtual environment '$(VENV_DIR)' does not exist."; \
		echo "Please run: 'make tests_build' first!"; \
		exit 1; \
	fi

	@for test in $(TESTS); do \
		echo "Running test: $$test"; \
		bash -c "source $(VENV_DIR)/bin/activate && set -a && source $(ENV_FILE) && set +a && pytest tests/test_$$test.py $(test_flags)"; \
	done

clean_files:
	find project/uploaded_files -mindepth 1 ! -name 'test_*' -exec rm -rf {} +
	find uploaded_files -mindepth 1 ! -name 'test_*' -exec rm -rf {} +

benchmark:
	@echo "Benchmarking with device=$(device), on machine=$(machine) in environment=$(environment)..."
	@if [ "$(environment)" != "dev" ]; then \
		echo "⚠️  This target should be run only on 'dev' environment"; \
		exit 1; \
	fi
	@if [ "$(device)" = "cuda" ]; then \
		echo "⚠️  Make sure the image was built with RUNTIME=nvidia"; \
	fi
	@if [ ! -f $(CSV_FILE) ]; then \
		echo "date;env;machine;task_name;server_execution_time(s);end_to_end_execution_time(s);device" > $(CSV_FILE); \
	fi

	@for task in $(TASKS); do \
		echo "Running $$task..."; \
		start=$$(date +%s.%N); \
		bash -c "source $(VENV_DIR)/bin/activate && set -a && source $(ENV_FILE) && set +a && pytest tests/test_$$task.py -vvs"; \
		end=$$(date +%s.%N); \
		end_to_end=$$(echo "$$end - $$start" | bc); \
		echo "🔍 Docker logs for task=$$task | e2e_time=$$end_to_end (s):"; \
		docker logs $(PREFIX)_service_celery_usecases_2 2>&1 | grep "🥕 ✅" | grep $$task | tail -n 1; \
		server_time=$$(docker logs $(PREFIX)_service_celery_usecases_2 2>&1 \
			| grep "🥕 ✅" \
			| grep "$$task" \
			| tail -n 1 \
			| grep -oP '\`[0-9.]+\`' \
			| tr -d '\`'); \
		echo "$(DATE);$(environment);$(machine);$$task;$$server_time;$$end_to_end;$(device)" >> $(CSV_FILE); \
	done

	mkdir -p images
	python update_benchmarks.py

stress_test:
	@echo "🔧 Loading environment configuration for $(environment)..."
	@if [ ! -f "$(ENV_FILE)" ]; then \
		echo "❌ Environment file .env_$(environment) not found!"; \
		exit 1; \
	fi
	@echo "🔧 Building test environment..."
	@make tests_build environment=$(environment)
	@echo "🔧 Generating stress test data..."
	@bash -c 'set -a && source .env_$(environment) && source $(VENV_DIR)/bin/activate && python tests/generate_stress_data.py'
	@echo "🚀 Running stress test against $(environment) server..."
	@bash -c 'set -a && source .env_$(environment) && source $(VENV_DIR)/bin/activate && python tests/stress_runner.py'

certificates:
	@if [ "$(environment)" = "dev" ]; then \
		echo "⚠️  This target should not be run in the 'dev' environment."; \
		echo "Development uses the HTTP protocol without secure connection."; \
		exit 1; \
	fi
	@echo "Building certificates for '$(environment)' using '$(ENV_FILE)' variables using 'sudo' privileges..."
	@if [ "$$(id -u)" -ne 0 ]; then \
		echo "This step requires sudo. Please run: 'sudo make certificates'"; \
		exit 1; \
	fi
	@bash -c ' \
		set -a && source $(ENV_FILE) && source .common_env && set +a && \
		bash ./scripts/generate_certificates.sh && \
		touch /tmp/certificates.done; \
	'

check_certificates:
	@bash -c ' \
		set -a && source $(ENV_FILE) && source .common_env && set +a; \
		if [ ! -f "$$HOST_CERTS_PATH/$$CERT_FILE_NAME" ] || [ ! -f "$$HOST_CERTS_PATH/$$PRIVKEY_FILE_NAME" ]; then \
			echo "❌ Certificate files are missing in $$HOST_CERTS_PATH."; \
			echo "Please run: sudo make certificates"; \
			exit 1; \
		else \
			echo "✅ Certificate files are present in $$HOST_CERTS_PATH."; \
		fi'
