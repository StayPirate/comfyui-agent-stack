# Configuration

All runtime knobs are read by Docker Compose from `.env` (copy
[`../.env.example`](../.env.example) to `.env`).

| Variable       | Default   | Description                                      |
| -------------- | --------- | ------------------------------------------------ |
| `PUID`/`PGID`  | `1000`    | Owner of files written into `./data`             |
| `TZ`           | `UTC`     | Container timezone                               |
| `COMFYUI_BIND` | `127.0.0.1` | Host bind address for the web UI               |
| `MCP_BIND`     | `127.0.0.1` | Host bind address for the MCP endpoint         |
| `COMFYUI_PORT` | `8188`    | **Host** port for the web UI (container listens on 8188) |
| `MCP_PORT`     | `8080`    | Host port for the MCP endpoint                   |
| `MCP_PATH`     | `/mcp`    | Path of the MCP endpoint                         |
| `MCP_STATEFUL` | `true`    | Streamable-HTTP session mode for the MCP bridge  |
| `MCP_DEBUG`    | `false`   | Verbose bridge logging                           |
| `COMFYUI_ARGS` | –         | Extra ComfyUI flags, e.g. `--lowvram`            |
| `COMFYUI_REF`  | `v0.36.0` | ComfyUI git ref baked into the image             |
| `COMFYUI_IMAGE`| local     | Image to run; pin a release tag (`:0.1.0`), not `:latest` |

`PUID`/`PGID` also govern the image's virtualenv ownership: the venv is built
for uid/gid `1000`, so runtime node/dependency installs (`install_node`,
`comfy node fix`) require `PUID=1000`. With a different `PUID`, run those through
`docker compose exec` (root) or rebuild the image with a matching uid.

## GPU / VRAM flags

`COMFYUI_ARGS` is the place for VRAM tuning on smaller cards:

- `--lowvram` — offload to system RAM, slower but fits smaller GPUs.
- `--novram` — most aggressive offload for very small cards.

On a 12 GB card such as an RTX 3060, `--lowvram` is often needed for video
models.

## Model search paths

By default ComfyUI only sees `./data/models`. To reuse a library that already
lives on the host, edit [`../config/extra_model_paths.yaml`](../config/extra_model_paths.yaml)
and add a bind mount for that directory in [`../compose.yaml`](../compose.yaml).

## Ports and exposure

Both ports bind to the loopback address by default, controlled by
`COMFYUI_BIND` and `MCP_BIND`. To open the web UI from another machine on a
trusted LAN, set `COMFYUI_BIND` to the host's LAN IP — or to `0.0.0.0` when a
firewall protects the host. Prefer a specific interface address over `0.0.0.0`.

Neither the web UI nor the MCP endpoint has **any authentication**. Exposing the
MCP port lets a client drive ComfyUI — including installing node packs, which
execute third-party code — so keep `MCP_BIND=127.0.0.1` and use an SSH tunnel or
an authenticating reverse proxy for remote access. Changing a bind address
requires recreating the container (`docker compose up -d`), not just a restart.

## Security

- Partner-API keys (`COMFY_API_KEY`) spend credits. Keep them in `.env` (ignored
  by git) and uncomment the mapping in `compose.yaml`.
- Node packs installed at runtime execute third-party code. Prefer packs from
  the ComfyUI Registry and review what you install.
- The image bundles GPL/AGPL components — see
  [`../THIRD_PARTY_LICENSES.md`](../THIRD_PARTY_LICENSES.md).