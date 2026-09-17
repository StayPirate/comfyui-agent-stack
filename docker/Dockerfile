# syntax=docker/dockerfile:1.7
# ---------------------------------------------------------------------------
# ComfyUI Agent Stack
# GPU-ready ComfyUI + comfy-cli + comfy-mcp, exposed to AI agents over MCP.
# ---------------------------------------------------------------------------
ARG CUDA_VERSION=12.4.1
ARG UBUNTU_VERSION=22.04

FROM nvidia/cuda:${CUDA_VERSION}-cudnn-runtime-ubuntu${UBUNTU_VERSION}

ARG DEBIAN_FRONTEND=noninteractive

# --- Pinned upstream versions (override with --build-arg) -------------------
ARG COMFYUI_REPO=https://github.com/comfyanonymous/ComfyUI.git
ARG COMFYUI_REF=master
ARG COMFY_CLI_SPEC=comfy-cli>=1.14.0
ARG COMFY_MCP_SPEC=comfy-mcp
ARG PYTORCH_INDEX_URL=https://download.pytorch.org/whl/cu124
ARG NODE_MAJOR=20
ARG SUPER_GATEWAY_SPEC=supergateway

ENV PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    VIRTUAL_ENV=/opt/venv \
    COMFYUI_DIR=/opt/ComfyUI \
    COMFY_BASELINE_DIR=/opt/comfy-baseline \
    PATH="/opt/venv/bin:${PATH}"

# --- System packages --------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
      python3 python3-venv python3-dev python3-pip \
      git curl ca-certificates gnupg \
      ffmpeg jq aria2 \
      build-essential \
      libgl1 libglib2.0-0 \
      tini gosu \
    && rm -rf /var/lib/apt/lists/*

RUN python3 -m venv "${VIRTUAL_ENV}" \
    && pip install --upgrade pip setuptools wheel

# --- PyTorch (heaviest layer; kept early for cache reuse) -------------------
RUN pip install --index-url "${PYTORCH_INDEX_URL}" torch torchvision torchaudio

# --- ComfyUI core (pinned by ref; resolved commit recorded) -----------------
RUN git clone "${COMFYUI_REPO}" "${COMFYUI_DIR}" \
    && git -C "${COMFYUI_DIR}" checkout "${COMFYUI_REF}" \
    && git -C "${COMFYUI_DIR}" rev-parse HEAD > /opt/ComfyUI.commit \
    && pip install -r "${COMFYUI_DIR}/requirements.txt"

# --- comfy-cli (engine) + comfy-mcp (stdio MCP server) ----------------------
RUN pip install "${COMFY_CLI_SPEC}" "${COMFY_MCP_SPEC}"

# --- Streamable-HTTP bridge (stdio MCP -> HTTP for agents) ------------------
RUN curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && npm install -g "${SUPER_GATEWAY_SPEC}" \
    && npm cache clean --force \
    && rm -rf /var/lib/apt/lists/*

# --- Baseline custom nodes (seed dir, copied into the volume at startup) ----
COPY docker/baseline-nodes.txt /tmp/baseline-nodes.txt
RUN set -eux; \
    mkdir -p "${COMFY_BASELINE_DIR}/custom_nodes"; \
    while read -r repo ref; do \
      [ -z "${repo:-}" ] && continue; \
      case "${repo}" in \#*) continue;; esac; \
      name="$(basename "${repo}" .git)"; \
      if [ -n "${ref:-}" ]; then \
        git clone --depth 1 --branch "${ref}" "${repo}" "${COMFY_BASELINE_DIR}/custom_nodes/${name}"; \
      else \
        git clone --depth 1 "${repo}" "${COMFY_BASELINE_DIR}/custom_nodes/${name}"; \
      fi; \
      if [ -f "${COMFY_BASELINE_DIR}/custom_nodes/${name}/requirements.txt" ]; then \
        pip install -r "${COMFY_BASELINE_DIR}/custom_nodes/${name}/requirements.txt" \
          || echo "warning: could not install requirements for ${name}"; \
      fi; \
    done < /tmp/baseline-nodes.txt; \
    rm -f /tmp/baseline-nodes.txt

# --- Non-root runtime user --------------------------------------------------
RUN groupadd -g 1000 comfy \
    && useradd -m -u 1000 -g 1000 -s /bin/bash comfy \
    && chown -R comfy:comfy "${COMFYUI_DIR}" "${COMFY_BASELINE_DIR}"

COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# --- Runtime defaults (override in compose/.env) ----------------------------
ENV COMFYUI_PORT=8188 \
    MCP_PORT=8080 \
    MCP_PATH=/mcp \
    MCP_STATEFUL=true \
    MCP_DEBUG=false \
    PUID=1000 \
    PGID=1000 \
    COMFYUI_ARGS=""

EXPOSE 8188 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=180s --retries=5 \
    CMD curl -fsS "http://127.0.0.1:${COMFYUI_PORT}/system_stats" >/dev/null || exit 1

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
