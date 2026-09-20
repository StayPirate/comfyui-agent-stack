# syntax=docker/dockerfile:1.7
# ---------------------------------------------------------------------------
# ComfyUI Agent Stack
# GPU-ready ComfyUI + comfy-cli + comfy-mcp, exposed to AI agents over MCP.
# ---------------------------------------------------------------------------
ARG CUDA_VERSION=12.6.3
ARG UBUNTU_VERSION=24.04

FROM nvidia/cuda:${CUDA_VERSION}-cudnn-runtime-ubuntu${UBUNTU_VERSION}

ARG DEBIAN_FRONTEND=noninteractive

# --- Pinned upstream versions (override with --build-arg) -------------------
# `# renovate:` annotations are consumed by Renovate (see renovate.json).
ARG COMFYUI_REPO=https://github.com/comfyanonymous/ComfyUI.git
# renovate: datasource=github-releases depName=comfyanonymous/ComfyUI
ARG COMFYUI_REF=v0.36.0
# renovate: datasource=pypi depName=comfy-cli
ARG COMFY_CLI_VERSION=1.20.0
# renovate: datasource=pypi depName=comfy-mcp
ARG COMFY_MCP_VERSION=0.10.0
ARG PYTORCH_INDEX_URL=https://download.pytorch.org/whl/cu126
# Newest mutually-compatible trio (torchaudio has no build newer than 2.11).
# renovate: datasource=pypi depName=torch
ARG TORCH_VERSION=2.11.0
# renovate: datasource=pypi depName=torchvision
ARG TORCHVISION_VERSION=0.26.0
# renovate: datasource=pypi depName=torchaudio
ARG TORCHAUDIO_VERSION=2.11.0
ARG NODE_MAJOR=24
# renovate: datasource=npm depName=supergateway
ARG SUPER_GATEWAY_VERSION=3.4.3

# --- Release metadata (overridden by CI from the git tag/commit) ------------
# Not managed by Renovate: `VERSION` is this project's SemVer, `REVISION` the
# commit the image was built from.
ARG VERSION=dev
ARG REVISION=unknown

ENV PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    VIRTUAL_ENV=/opt/venv \
    COMFYUI_DIR=/opt/ComfyUI \
    COMFY_BASELINE_DIR=/opt/comfy-baseline \
    PATH="/opt/venv/bin:${PATH}"

# --- Image metadata ---------------------------------------------------------
# OCI labels make the image traceable back to a release and record exactly
# which upstream components it bundles (`docker inspect` reports all of them).
LABEL org.opencontainers.image.title="ComfyUI Agent Stack" \
      org.opencontainers.image.description="GPU-ready ComfyUI + comfy-cli + comfy-mcp, exposed to AI agents over MCP" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${REVISION}" \
      org.opencontainers.image.source="https://github.com/StayPirate/comfyui-agent-stack" \
      org.opencontainers.image.url="https://github.com/StayPirate/comfyui-agent-stack" \
      org.opencontainers.image.licenses="MIT" \
      io.github.staypirate.comfyui-agent-stack.comfyui-ref="${COMFYUI_REF}" \
      io.github.staypirate.comfyui-agent-stack.comfy-cli-version="${COMFY_CLI_VERSION}" \
      io.github.staypirate.comfyui-agent-stack.comfy-mcp-version="${COMFY_MCP_VERSION}" \
      io.github.staypirate.comfyui-agent-stack.pytorch-version="${TORCH_VERSION}"

# --- System packages --------------------------------------------------------
# The multimedia block covers the system libraries that common image/video/audio
# node packs need to build or call (pip cannot provide them, and apt installs
# made by an agent at runtime do not survive a container rebuild):
#   portaudio19-dev -> PyAudio / sounddevice / soundcard
#   libsndfile1-dev -> soundfile / libsndfile bindings
#   fluidsynth(+dev)-> pyfluidsynth / midi2audio (the `fluidsynth` binary)
#   sox, libsox-fmt-all -> packs shelling out to sox
#   libsamplerate0-dev -> samplerate / resampy
#   libsm6 -> some OpenCV/GUI-based nodes
RUN apt-get update && apt-get install -y --no-install-recommends \
      python3 python3-venv python3-dev python3-pip \
      git curl ca-certificates gnupg \
      ffmpeg jq aria2 \
      build-essential \
      libgl1 libglib2.0-0 \
      portaudio19-dev libsndfile1-dev libsamplerate0-dev \
      fluidsynth libfluidsynth-dev \
      sox libsox-fmt-all \
      libsm6 \
      tini gosu \
    && rm -rf /var/lib/apt/lists/*

# --- Runtime user (created before the venv so the venv is owned by it) ------
# Ubuntu base images already ship a uid/gid 1000 account, so allow non-unique
# IDs; the entrypoint remaps this user to PUID/PGID at runtime. Every pip
# install below runs as this user, so the venv is writable at runtime and
# Manager/comfy-cli can install node-pack dependencies without root.
RUN groupadd -o -g 1000 comfy \
    && useradd -o -m -u 1000 -g 1000 -s /bin/bash comfy

RUN python3 -m venv "${VIRTUAL_ENV}" \
    && chown -R comfy:comfy "${VIRTUAL_ENV}" \
    && gosu comfy pip install --upgrade pip setuptools wheel

# --- PyTorch (heaviest layer; kept early for cache reuse) -------------------
# Pinned as a compatible trio; cu126 matches the CUDA 12.6 base image.
RUN gosu comfy pip install --index-url "${PYTORCH_INDEX_URL}" \
      "torch==${TORCH_VERSION}" \
      "torchvision==${TORCHVISION_VERSION}" \
      "torchaudio==${TORCHAUDIO_VERSION}"

# --- ComfyUI core (pinned by ref; resolved commit recorded) -----------------
RUN git clone "${COMFYUI_REPO}" "${COMFYUI_DIR}" \
    && git -C "${COMFYUI_DIR}" checkout "${COMFYUI_REF}" \
    && git -C "${COMFYUI_DIR}" rev-parse HEAD > /opt/ComfyUI.commit \
    && gosu comfy pip install -r "${COMFYUI_DIR}/requirements.txt"

# --- ComfyUI-Manager (pip package, required by comfy-cli --enable-manager) --
# ComfyUI ships the pinned manager version in manager_requirements.txt; without
# it comfy-cli cannot inject --enable-manager and the legacy git-clone Manager
# is blocked by policy, leaving node installs broken. Guarded for older refs
# that predate the file.
RUN if [ -f "${COMFYUI_DIR}/manager_requirements.txt" ]; then \
      gosu comfy pip install -r "${COMFYUI_DIR}/manager_requirements.txt"; \
    else \
      echo "warning: ${COMFYUI_DIR}/manager_requirements.txt not found"; \
    fi

# --- comfy-cli (engine) + comfy-mcp (stdio MCP server) ----------------------
RUN gosu comfy pip install "comfy-cli==${COMFY_CLI_VERSION}" "comfy-mcp==${COMFY_MCP_VERSION}"

# --- Streamable-HTTP bridge (stdio MCP -> HTTP for agents) ------------------
RUN curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && npm install -g "supergateway@${SUPER_GATEWAY_VERSION}" \
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
        gosu comfy pip install -r "${COMFY_BASELINE_DIR}/custom_nodes/${name}/requirements.txt" \
          || echo "warning: could not install requirements for ${name}"; \
      fi; \
    done < /tmp/baseline-nodes.txt; \
    rm -f /tmp/baseline-nodes.txt

# --- Build-time sanity check (no post-build image pull needed) --------------
# The PyTorch import catches an ABI-incompatible torch/torchvision/torchaudio
# combination before the image is published (e.g. a Renovate bump of only one).
RUN comfy --version \
    && comfy-mcp --help >/dev/null \
    && supergateway --help >/dev/null \
    && PYTHONPATH="${COMFYUI_DIR}" python -c "import comfyui_manager, cm_cli; print('manager ok')" \
    && python -c "import torch, torchvision, torchaudio; print('torch', torch.__version__)"

# --- Ownership of the runtime trees -----------------------------------------
# The venv is already owned by `comfy` (pip ran as that user). Hand over the
# source trees too so ComfyUI can write bytecode caches at runtime.
RUN chown -R comfy:comfy "${COMFYUI_DIR}" "${COMFY_BASELINE_DIR}"

COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# --- Runtime defaults (override in compose/.env) ----------------------------
# NB: the in-container ComfyUI port is COMFY_HTTP_PORT, not COMFYUI_PORT:
# comfy-mcp reserves COMFYUI_PORT for a remote target and errors when it is set
# without COMFYUI_HOST.
ENV COMFY_HTTP_PORT=8188 \
    MCP_PORT=8080 \
    MCP_PATH=/mcp \
    MCP_STATEFUL=true \
    MCP_DEBUG=false \
    PUID=1000 \
    PGID=1000 \
    COMFYUI_ARGS=""

EXPOSE 8188 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=180s --retries=5 \
    CMD curl -fsS "http://127.0.0.1:${COMFY_HTTP_PORT}/system_stats" >/dev/null || exit 1

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
