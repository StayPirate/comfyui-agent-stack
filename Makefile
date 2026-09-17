SHELL := /bin/bash
COMPOSE ?= docker compose

.DEFAULT_GOAL := help

.PHONY: help up down logs build rebuild pull shell ui mcp-url ps bootstrap clean

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	  awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

up: ## Start the stack in the background
	$(COMPOSE) up -d

down: ## Stop the stack (keeps ./data)
	$(COMPOSE) down

logs: ## Follow container logs
	$(COMPOSE) logs -f --tail=200

build: ## Build the image locally
	$(COMPOSE) build

rebuild: ## Rebuild the image and recreate the container
	$(COMPOSE) up -d --build

pull: ## Pull the image configured in .env
	$(COMPOSE) pull

ps: ## Show container status
	$(COMPOSE) ps

shell: ## Open a shell inside the container
	$(COMPOSE) exec comfyui bash

ui: ## Print the ComfyUI web UI URL
	@echo "http://127.0.0.1:$${COMFYUI_PORT:-8188}"

mcp-url: ## Print the MCP endpoint for agent clients
	@echo "http://127.0.0.1:$${MCP_PORT:-8080}$${MCP_PATH:-/mcp}"

bootstrap: ## Download models listed in models.manifest.txt
	./scripts/bootstrap-models.sh

clean: ## Stop the stack and remove containers/networks (keeps ./data)
	$(COMPOSE) down --remove-orphans
