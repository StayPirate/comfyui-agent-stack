#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# ComfyUI Agent Stack entrypoint
#   1. map the runtime user to PUID/PGID (bind-mount friendly)
#   2. seed baseline custom nodes
#   3. start ComfyUI (via comfy-cli, so its logs are available to MCP tools)
#   4. wait for readiness
#   5. expose the comfy-mcp stdio server over Streamable HTTP
# ---------------------------------------------------------------------------
set -euo pipefail

PUID="${PUID:-1000}"
PGID="${PGID:-1000}"
COMFYUI_PORT="${COMFYUI_PORT:-8188}"
MCP_PORT="${MCP_PORT:-8080}"
MCP_PATH="${MCP_PATH:-/mcp}"
MCP_STATEFUL="${MCP_STATEFUL:-true}"
MCP_DEBUG="${MCP_DEBUG:-false}"
COMFYUI_DIR="${COMFYUI_DIR:-/opt/ComfyUI}"
COMFY_BASELINE_DIR="${COMFY_BASELINE_DIR:-/opt/comfy-baseline}"
COMFYUI_ARGS="${COMFYUI_ARGS:-}"

log() { printf '[entrypoint] %s\n' "$*" >&2; }

# --- 1. Map the comfy user to the requested UID/GID -------------------------
mapped=false
if [ "$(id -g comfy)" != "${PGID}" ]; then groupmod -o -g "${PGID}" comfy; mapped=true; fi
if [ "$(id -u comfy)" != "${PUID}" ]; then usermod -o -u "${PUID}" comfy; mapped=true; fi
if [ "${mapped}" = true ]; then
  log "comfy user mapped to ${PUID}:${PGID}"
fi

# --- 2. Ensure data directories exist --------------------------------------
mkdir -p "${COMFYUI_DIR}"/{models,input,output,custom_nodes,user}

# --- 3. Seed baseline custom nodes (never overwrite user changes) ----------
if [ -d "${COMFY_BASELINE_DIR}/custom_nodes" ]; then
  cp -rn "${COMFY_BASELINE_DIR}"/custom_nodes/. "${COMFYUI_DIR}/custom_nodes/" 2>/dev/null || true
fi

# --- 4. Make mounted directories writable by the runtime user --------------
chown -R comfy:comfy \
  "${COMFYUI_DIR}/models" \
  "${COMFYUI_DIR}/input" \
  "${COMFYUI_DIR}/output" \
  "${COMFYUI_DIR}/custom_nodes" \
  "${COMFYUI_DIR}/user"

# --- 5. Register the workspace so comfy-cli/comfy-mcp target it ------------
gosu comfy comfy set-default "${COMFYUI_DIR}" >/dev/null 2>&1 \
  || log "warning: 'comfy set-default' failed; relying on cwd"
cd "${COMFYUI_DIR}"

# --- 6. Start ComfyUI -------------------------------------------------------
log "launching ComfyUI on 0.0.0.0:${COMFYUI_PORT}"
launch_log="$(mktemp)"
# Extra ComfyUI flags go after `--` (comfy-cli forwards them to main.py).
# shellcheck disable=SC2086
if ! gosu comfy comfy launch --background -- --listen 0.0.0.0 --port "${COMFYUI_PORT}" ${COMFYUI_ARGS} \
    >"${launch_log}" 2>&1; then
  log "ERROR: 'comfy launch' failed; output follows"
  sed 's/^/[comfy launch] /' "${launch_log}" >&2 || true
  comfy_log="${COMFYUI_DIR}/user/comfyui_${COMFYUI_PORT}.log"
  if [ -f "${comfy_log}" ]; then
    log "last lines of ${comfy_log}:"
    tail -n 40 "${comfy_log}" >&2 || true
  fi
  rm -f "${launch_log}"
  exit 1
fi
rm -f "${launch_log}"

# --- 7. Wait until the API answers ------------------------------------------
ready=false
for _ in $(seq 1 150); do
  if curl -fsS "http://127.0.0.1:${COMFYUI_PORT}/system_stats" >/dev/null 2>&1; then
    ready=true
    break
  fi
  sleep 2
done
if [ "${ready}" != true ]; then
  log "ERROR: ComfyUI did not become ready within the timeout"
  exit 1
fi
log "ComfyUI is ready"

# --- 8. Watchdog: let compose restart the container on a dead backend -------
(
  fails=0
  while true; do
    sleep 20
    if curl -fsS "http://127.0.0.1:${COMFYUI_PORT}/system_stats" >/dev/null 2>&1; then
      fails=0
    else
      fails=$((fails + 1))
      log "watchdog: ComfyUI unresponsive (${fails}/3)"
      if [ "${fails}" -ge 3 ]; then
        log "watchdog: terminating container for restart"
        kill -TERM 1 2>/dev/null || exit 1
      fi
    fi
  done
) &

# --- 9. Expose the MCP server over Streamable HTTP --------------------------
bridge_args=(
  --stdio "comfy-mcp"
  --outputTransport streamableHttp
  --port "${MCP_PORT}"
  --streamableHttpPath "${MCP_PATH}"
)
if [ "${MCP_STATEFUL}" = "true" ]; then bridge_args+=(--stateful); fi
if [ "${MCP_DEBUG}" = "true" ]; then bridge_args+=(--logLevel debug); fi

log "starting MCP bridge on 0.0.0.0:${MCP_PORT}${MCP_PATH}"
exec gosu comfy supergateway "${bridge_args[@]}"
