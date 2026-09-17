# ComfyUI Agent Stack

A GPU-ready, agent-native ComfyUI in a single container.

It bundles **[ComfyUI](https://github.com/comfyanonymous/ComfyUI)**, **comfy-cli**
and the official **[comfy-mcp](https://github.com/Comfy-Org/comfy-mcp)** server,
and exposes ComfyUI to any MCP-speaking AI agent (opencode, Claude Code,
Claude Desktop, Cursor, Codex, …) over Streamable HTTP.

The goal: start the stack, point your agent at it, and ask in plain language —
*"create an image of…", "make a 5-second video of…", "generate a song about…"*.
The agent discovers templates and nodes, installs what is missing, downloads the
required models, validates the workflow, runs it and collects the output.

- **Model-free image.** Models are downloaded on demand into a persistent volume
  (smaller image, no model licensing headaches).
- **Persistent storage.** Config, inputs, outputs, models, custom nodes and user
  settings live in `./data`, easy to back up and inspect.
- **Two-tier custom nodes.** A small pinned baseline is always seeded; the agent
  installs workflow-specific packs on demand via ComfyUI-Manager.
- **CI/CD ready.** GitHub Actions builds and publishes multi-stage images to
  `ghcr.io` with SBOM and provenance attestations.

> Status: experimental. ComfyUI, comfy-cli and comfy-mcp evolve quickly — pin
> versions for reproducible builds.

---

## Requirements

- Docker with the Compose plugin
- An NVIDIA GPU and a working **NVIDIA Container Toolkit** on the host
  - Arch Linux users: see [`docs/nvidia-arch.md`](docs/nvidia-arch.md)
  - Other distros: <https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html>
- ~15 GB of disk for the image, plus space for models in `./data/models`

No NVIDIA GPU? You can still run workflows that use **partner-API nodes**
(hosted models billed as credits) by setting `COMFY_API_KEY`, or run the CPU
profile for validation only (see [`compose.cpu.yaml`](compose.cpu.yaml)).

---

## Quickstart

```bash
git clone https://github.com/StayPirate/comfyui-agent-stack.git
cd comfyui-agent-stack

cp .env.example .env
# edit .env: set PUID/PGID (id -u / id -g), TZ, and optionally COMFYUI_IMAGE

make up          # or: docker compose up -d
make logs        # follow startup; wait for "ComfyUI is ready"
```

Then open the ComfyUI UI at <http://127.0.0.1:8188>.

The MCP endpoint for agents is <http://127.0.0.1:8080/mcp>.

### Connect opencode

Copy [`examples/opencode.jsonc`](examples/opencode.jsonc) into your opencode
config (`~/.config/opencode/opencode.json`):

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "comfyui": {
      "type": "remote",
      "url": "http://127.0.0.1:8080/mcp",
      "enabled": true
    }
  }
}
```

Restart opencode, then try:

> Check that my local ComfyUI is running, find a text-to-image template, run it
> with the prompt "a fox in a snowy forest", and show me the result.

The agent will call `server_info`, `search_templates`, `fetch_template`,
`validate_workflow`, `run_workflow` and `fetch_outputs` on your behalf. See
[`AGENTS.md`](AGENTS.md) for the intended workflow and tips.

---

## Storage layout

Everything persistent lives on the host, under `./data` and `./config`:

| Host path                 | Container path                     | Purpose                          |
| ------------------------- | ---------------------------------- | -------------------------------- |
| `data/models/`            | `/opt/ComfyUI/models`              | checkpoints, LoRAs, VAE, …       |
| `data/input/`             | `/opt/ComfyUI/input`               | source images/masks              |
| `data/output/`            | `/opt/ComfyUI/output`              | generated images/video/audio     |
| `data/custom_nodes/`      | `/opt/ComfyUI/custom_nodes`        | installed node packs             |
| `data/user/`              | `/opt/ComfyUI/user`                | UI settings, workflows, logs     |
| `config/extra_model_paths.yaml` | `/opt/ComfyUI/extra_model_paths.yaml` | extra model search paths    |

Files are owned by `PUID:PGID` from `.env`, so outputs are readable on the host
without `sudo`.

---

## Models

Models are **not** baked into the image. There are two ways to get them:

1. **Let the agent do it.** Ask for a result; the agent uses `search_models` /
   `download_model` (or `comfy model download`) and `validate_workflow` to fetch
   exactly what the workflow needs. This is the intended flow.
2. **Pre-seed a set.** List URLs in [`models.manifest.txt`](models.manifest.txt)
   and run `make bootstrap` (uses `aria2c` if available, otherwise `curl`).

Models are written to `./data/models/<type>/`.

---

## Configuration

All knobs live in `.env` (see [`.env.example`](.env.example)):

| Variable       | Default | Description                                      |
| -------------- | ------- | ------------------------------------------------ |
| `PUID`/`PGID`  | `1000`  | Owner of files in `./data`                       |
| `TZ`           | `UTC`   | Container timezone                               |
| `COMFYUI_PORT` | `8188`  | Host port for the web UI                         |
| `MCP_PORT`     | `8080`  | Host port for the MCP endpoint                   |
| `MCP_PATH`     | `/mcp`  | Path of the MCP endpoint                         |
| `MCP_STATEFUL` | `true`  | Streamable-HTTP session mode for the MCP bridge  |
| `COMFYUI_ARGS` | –       | Extra ComfyUI flags, e.g. `--lowvram`            |
| `COMFYUI_REF`  | `master`| ComfyUI git ref baked into the image             |
| `COMFYUI_IMAGE`| local   | Image tag; point to `ghcr.io/<you>/…` to consume |

### GPU VRAM flags

`COMFYUI_ARGS` is the place for VRAM tuning on smaller cards, e.g.
`--lowvram` or `--novram`. On an RTX 3060 (12 GB) `--lowvram` is often useful
for video models.

---

## Security

- Both ports are bound to `127.0.0.1` in `compose.yaml`. The MCP endpoint has
  **no authentication** — do not expose it to a network you do not trust.
- To reach it from another machine, put it behind an authenticating reverse proxy
  or an SSH tunnel, and change the port binding deliberately.
- Partner-API keys (`COMFY_API_KEY`) spend credits. Keep them in `.env` (ignored
  by git) and uncomment the mapping in `compose.yaml`.

---

## Publishing to GHCR

The workflow in [`.github/workflows/build-push.yml`](.github/workflows/build-push.yml)
builds `linux/amd64` on every push to `main`, PRs (build only) and `v*` tags, and
pushes to `ghcr.io/<owner>/<repo>` with `latest`, branch, semver and `sha` tags.

To consume a published image:

```bash
# .env
COMFYUI_IMAGE=ghcr.io/<owner>/comfyui-agent-stack:latest
```

```bash
docker compose pull && docker compose up -d
```

Make the package public in the repository's *Packages* settings if you want
anonymous pulls.

---

## Building with specific versions

```bash
docker compose build \
  --build-arg COMFYUI_REF=v0.3.60 \
  --build-arg COMFY_MCP_SPEC=comfy-mcp==<version>
```

`COMFYUI_REF` can be any branch, tag or commit. For reproducible images, pin a
tag or commit and consider enabling Renovate/Dependabot for updates.

---

## Documentation

- [`AGENTS.md`](AGENTS.md) — how agents should use the stack
- [`docs/architecture.md`](docs/architecture.md) — how the pieces fit together
- [`docs/nvidia-arch.md`](docs/nvidia-arch.md) — NVIDIA Container Toolkit on Arch
- [`docs/custom-nodes.md`](docs/custom-nodes.md) — baseline vs. on-demand nodes
- [`docs/troubleshooting.md`](docs/troubleshooting.md) — common issues

---

## License

This repository is MIT-licensed ([`LICENSE`](LICENSE)). The **image** bundles
third-party software under their own licenses — notably ComfyUI (GPL-3.0) and
comfy-mcp (AGPL-3.0-or-later OR commercial). See
[`THIRD_PARTY_LICENSES.md`](THIRD_PARTY_LICENSES.md). Models are never
redistributed by this project.
