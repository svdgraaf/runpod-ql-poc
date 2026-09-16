# Runpod hosts are linux/amd64. This Mac is arm64, so every build is explicit
# about the platform. `make run` uses qemu, which is slow but correct.
DOCKER_USER ?= svdgraafrunpod
IMAGE       ?= docker.io/$(DOCKER_USER)/runpod-ql-poc
TAG         ?= dev
PLATFORM    ?= linux/amd64

# Network volume, reached over Runpod's S3-compatible API. The bucket is the
# network volume ID; the region is the datacenter ID, lowercased in the host.
# Credentials come from AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY (console ->
# Settings -> S3 API Keys), never from this file.
DATACENTER     ?= eur-is-1
NETWORK_VOLUME ?= ay4uw9ekrt
S3_ENDPOINT    ?= https://s3api-$(DATACENTER).runpod.io
REMOTE_DIR     ?= app

# aws-cli 2.23+ sends CRC32 checksums by default, which S3-compatible backends
# often reject. "when_required" keeps them off unless the API asks for them.
AWS_ENV = AWS_REQUEST_CHECKSUM_CALCULATION=when_required

.PHONY: help build push run shell sync ls check-aws-creds clean

help:
	@echo "build  - build $(IMAGE):$(TAG) for $(PLATFORM) into the local docker images"
	@echo "push   - build and push $(IMAGE):$(TAG) for $(PLATFORM)"
	@echo "shell  - shell in the image, ./app mounted"
	@echo "sync   - upload ./app to s3://$(NETWORK_VOLUME)/$(REMOTE_DIR) ($(DATACENTER))"
	@echo "ls     - list what is on the volume now"
	@echo ""
	@echo "override: make push DOCKER_USER=... TAG=..."
	@echo "          make sync NETWORK_VOLUME=... DATACENTER=..."

build:
	docker buildx build --platform $(PLATFORM) -t $(IMAGE):$(TAG) --load .

push:
	docker buildx build --platform $(PLATFORM) -t $(IMAGE):$(TAG) --push .

shell:
	docker run --rm -it --platform $(PLATFORM) \
		-v $(PWD)/app:/runpod-volume/app:ro \
		-e RUNPOD_HOT_RELOAD=1 \
		--entrypoint bash $(IMAGE):$(TAG)

# Upload user code to the network volume. This is the whole deploy: no build,
# no push, no restart. --delete is on by default, so a file renamed locally
# stops being imported on the worker instead of lingering as a stale module.
# Pass SYNC_FLAGS= to turn it off.
SYNC_FLAGS ?= --delete

sync: check-aws-creds
	$(AWS_ENV) aws s3 sync ./app s3://$(NETWORK_VOLUME)/$(REMOTE_DIR) \
		--region $(DATACENTER) \
		--endpoint-url $(S3_ENDPOINT) \
		--exclude '__pycache__/*' \
		$(SYNC_FLAGS)

ls: check-aws-creds
	$(AWS_ENV) aws s3 ls s3://$(NETWORK_VOLUME)/$(REMOTE_DIR)/ \
		--region $(DATACENTER) \
		--endpoint-url $(S3_ENDPOINT)

# Reads the shell's environment ($$VAR), not make's expansion of it, so the
# secret never lands in the printed recipe.
check-aws-creds:
	@test -n "$$AWS_ACCESS_KEY_ID" -a -n "$$AWS_SECRET_ACCESS_KEY" || { \
		echo "AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY not set."; \
		echo "Create an S3 API key: Runpod console -> Settings -> S3 API Keys."; \
		exit 1; }

clean:
	docker image rm $(IMAGE):$(TAG) || true
