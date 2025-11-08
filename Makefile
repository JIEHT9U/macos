# Makefile to build and run the Docker image for this project.
# Place this file in the `macos/` directory next to the `Dockerfile`.
#
# Usage:
#   make build                 Build the image (tag: $(IMAGE_NAME):$(TAG))
#   make build-no-cache        Build image without cache
#   make run                  Run the container interactively (removes container on exit)
#   make run-detached         Run container in background (detached)
#   make shell                Start a shell in a disposable container
#   make stop                 Stop the running container (if exists)
#   make logs                 Follow logs from the running container
#   make tag REGISTRY=...     Tag image for a registry
#   make push REGISTRY=...    Push tagged image to registry
#   make help                 Show this help
#
# Adjust variables below as needed.

IMAGE_NAME ?= macos
TAG ?= local
FULL_TAG := $(IMAGE_NAME):$(TAG)

DOCKERFILE ?= Dockerfile
CONTEXT ?= .

# Optional: pass build args to docker. Example:
#   make build VERSION_ARG=0.1.2
BUILD_ARGS :=
ifdef VERSION_ARG
BUILD_ARGS += --build-arg VERSION_ARG=$(VERSION_ARG)
endif
ifdef VERSION_OPENCORE
BUILD_ARGS += --build-arg VERSION_OPENCORE=$(VERSION_OPENCORE)
endif
ifdef VERSION_KVM_OPENCORE
BUILD_ARGS += --build-arg VERSION_KVM_OPENCORE=$(VERSION_KVM_OPENCORE)
endif

# Container runtime settings
CONTAINER_NAME ?= macos_dev
PORTS ?= -p 5900:5900 -p 8006:8006
VOLUMES ?= -v $(CURDIR)/storage:/storage
# If you want to expose additional devices, GPUs, or pass privileged, edit RUN_OPTS
RUN_OPTS ?= --rm -it --name $(CONTAINER_NAME) $(PORTS) $(VOLUMES)

# Default help target
.PHONY: help
help:
	@echo "Makefile targets:"
	@echo "  make build [VERSION_ARG=...]     Build docker image ($(FULL_TAG))"
	@echo "  make build-no-cache [..]         Build without cache"
	@echo "  make run                         Run container interactively (uses ENTRYPOINT)"
	@echo "  make run-detached                Run container detached"
	@echo "  make shell                       Start a shell in a disposable container"
	@echo "  make stop                        Stop the running container"
	@echo "  make logs                        Follow container logs"
	@echo "  make tag REGISTRY=...            Tag image for remote registry"
	@echo "  make push REGISTRY=...           Push tagged image to registry"
	@echo ""
	@echo "Variables you can override on the command line:"
	@echo "  IMAGE_NAME TAG DOCKERFILE CONTEXT CONTAINER_NAME PORTS VOLUMES"

# Build image (default, uses cache)
.PHONY: build
build:
	@echo "Building Docker image: $(FULL_TAG)"
	docker build -f $(DOCKERFILE) -t $(FULL_TAG) $(BUILD_ARGS) $(CONTEXT)

# Build without cache
.PHONY: build-no-cache
build-no-cache:
	@echo "Building Docker image (no cache): $(FULL_TAG)"
	docker build --no-cache -f $(DOCKERFILE) -t $(FULL_TAG) $(BUILD_ARGS) $(CONTEXT)

# Run container interactively (removes container on exit)
.PHONY: run
run:
	@echo "Running container: $(CONTAINER_NAME)"
	docker run $(RUN_OPTS) $(FULL_TAG)

# Run container detached (background)
.PHONY: run-detached
run-detached:
	@echo "Running container detached: $(CONTAINER_NAME)"
	docker run -d --name $(CONTAINER_NAME) $(PORTS) $(VOLUMES) $(FULL_TAG)

# Start a shell in a disposable container (tries /bin/bash, falls back to /bin/sh)
.PHONY: shell
shell:
	@echo "Starting shell in image $(FULL_TAG)"
	@if docker image inspect $(FULL_TAG) > /dev/null 2>&1; then \
		docker run --rm -it $(VOLUMES) --entrypoint /bin/bash $(FULL_TAG) || \
		docker run --rm -it $(VOLUMES) --entrypoint /bin/sh $(FULL_TAG); \
	else \
		echo "Image $(FULL_TAG) not found. Build it first with 'make build'."; exit 1; \
	fi

# Stop container if running
.PHONY: stop
stop:
	-@docker ps -q --filter "name=$(CONTAINER_NAME)" | grep -q . && docker stop $(CONTAINER_NAME) || echo "No running container named $(CONTAINER_NAME)"

# Follow logs
.PHONY: logs
logs:
	@docker logs -f $(CONTAINER_NAME)

# Tag image for registry
# Usage: make tag REGISTRY=myregistry.example.com/myrepo
.PHONY: tag
tag:
ifndef REGISTRY
	$(error REGISTRY is not set. Usage: make tag REGISTRY=your.registry/yourrepo)
endif
	@echo "Tagging image $(FULL_TAG) -> $(REGISTRY)/$(IMAGE_NAME):$(TAG)"
	docker tag $(FULL_TAG) $(REGISTRY)/$(IMAGE_NAME):$(TAG)

# Push image to registry (tag first or use tag target)
# Usage: make push REGISTRY=myregistry.example.com/myrepo
.PHONY: push
push:
ifndef REGISTRY
	$(error REGISTRY is not set. Usage: make push REGISTRY=your.registry/yourrepo)
endif
	@echo "Pushing image to $(REGISTRY)/$(IMAGE_NAME):$(TAG)"
	docker push $(REGISTRY)/$(IMAGE_NAME):$(TAG)

# Convenience: remove image locally
.PHONY: rmi
rmi:
	@docker image rm -f $(FULL_TAG) || true

# Clean: stop container and remove it
.PHONY: clean
clean: stop
	-@docker rm -f $(CONTAINER_NAME) 2>/dev/null || true
