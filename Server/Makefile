include .common_env
export

VENV_DIR=.venv_test

# Pytest flags
test_flags ?= -vvs
# Target environment (dev, staging, prod, ci)        
environment ?= dev
# Docker build cache option. Use '' to enable cache or '--no-cache' to disable it        
cache ?=
# Force Rust rebuild. Use '' to enable cache or '--rebuild_rust' to disable it      
rebuild_rust ?=

.PHONY: docker_build docker_run docker_build_run tests_build tests_run clean_files

docker_build:
	sudo bash ./scripts/docker_build.sh $(environment) $(cache) $(rebuild_rust)

docker_run:
	@if [ $$(docker images | grep $$FINAL_IMAGE_NAME | wc -l) -eq 0 ]; then \
		echo "❌ The docker image '$$FINAL_IMAGE_NAME' does not exist."; \
		echo "Please run: 'make docker_build' first!"; \
		exit 1; \
	fi
	sudo bash ./scripts/docker_run.sh $(environment)

docker_build_run:
	sudo bash ./scripts/docker_build.sh $(environment) $(cache) $(rebuild_rust)
	sudo bash ./scripts/docker_run.sh $(environment)

tests_build:
	VENV_DIR=$(VENV_DIR) bash ./scripts/tests_build.sh

tests_run:
	@if [ ! -d "$(VENV_DIR)" ]; then \
		echo "❌ Virtual environment '$(VENV_DIR)' does not exist."; \
		echo "Please run: 'make tests_build' first!"; \
		exit 1; \
	fi
	bash -c "source $(VENV_DIR)/bin/activate && pytest tests/test_endpoints.py $(test_flags)"

clean_files:
	find project/uploaded_files -mindepth 1 ! -name 'test_*' -exec rm -rf {} +
	find uploaded_files -mindepth 1 ! -name 'test_*' -exec rm -rf {} +
