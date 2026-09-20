# ComfyUI Agent Stack

**A GPU-ready, agent-native ComfyUI in one container.** It bundles
[ComfyUI](https://github.com/comfyanonymous/ComfyUI), [comfy-cli](https://github.com/Comfy-Org/comfy-cli)
and the official [comfy-mcp](https://github.com/Comfy-Org/comfy-mcp) server, and
exposes ComfyUI to any MCP-speaking agent (opencode, Claude Code, Claude Desktop,
Cursor, Codex, …) over Streamable HTTP.

[![build-push](https://github.com/StayPirate/comfyui-agent-stack/actions/workflows/build-push.yml/badge.svg)](https://github.com/StayPirate/comfyui-agent-stack/actions/workflows/build-push.yml)
[![lint](https://github.com/StayPirate/comfyui-agent-stack/actions/workflows/lint.yml/badge.svg)](https://github.com/StayPirate/comfyui-agent-stack/actions/workflows/lint.yml)
[![security-scan](https://github.com/StayPirate/comfyui-agent-stack/actions/workflows/trivy.yml/badge.svg)](https://github.com/StayPirate/comfyui-agent-stack/actions/workflows/trivy.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![GitHub release](https://img.shields.io/github/v/release/StayPirate/comfyui-agent-stack?sort=semver&logo=github)](https://github.com/StayPirate/comfyui-agent-stack/releases)
[![ghcr.io](https://img.shields.io/badge/ghcr.io-comfyui--agent--stack-blue?logo=github)](https://github.com/StayPirate/comfyui-agent-stack/pkgs/container/comfyui-agent-stack)

Start the stack, point your agent at it, and ask in plain language:
*"create an image of…", "make a 5-second video of…", "generate a song about…"*.
The agent finds templates, installs missing nodes, downloads the models,
validates the workflow, runs it and collects the output.

- **Model-free image** — models are fetched on demand into a persistent volume
  (smaller image, no model licensing headaches).
- **Persistent storage** — config, inputs, outputs, models, custom nodes and
  user settings live in `./data`, easy to back up and inspect.
- **Two-tier custom nodes** — ComfyUI-Manager ships as a pip package; a small
  pinned baseline is seeded on first start and workflow-specific packs are
  installed on demand by the agent.
- **Media-ready base** — the system libraries common image/video/audio node
  packs need (`portaudio19-dev`, `libsndfile1-dev`, `fluidsynth`, `sox`, …) are
  baked in, so their Python dependencies install without manual `apt`.
- **CI/CD ready** — GitHub Actions publishes to `ghcr.io` with SBOM and
  provenance, plus a weekly security scan and Renovate updates. Releases are
  [SemVer-tagged](docs/publishing.md#versioning); pin one (e.g.
  `:0.1.0`) instead of `:latest`, which tracks `main`.

## Requirements

- Docker with the Compose plugin
- An NVIDIA GPU with a working **NVIDIA Container Toolkit**
  - Arch Linux: see [`docs/nvidia-arch.md`](docs/nvidia-arch.md)
  - Other distros: [install guide](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)
- ~15 GB for the image, plus space for models

No NVIDIA GPU? You can use **partner-API nodes** (hosted models, billed as
credits) via `COMFY_API_KEY`, or the CPU profile for validation only
([`compose.cpu.yaml`](compose.cpu.yaml)).

## Quickstart

```bash
git clone https://github.com/StayPirate/comfyui-agent-stack.git
cd comfyui-agent-stack

cp .env.example .env     # set PUID/PGID (id -u / id -g) and TZ
make up                  # or: docker compose up -d
make logs                # wait for "ComfyUI is ready"
```

- Web UI: <http://127.0.0.1:8188>
- MCP endpoint: <http://127.0.0.1:8080/mcp>

To open the web UI from another machine on your LAN, set `COMFYUI_BIND` in
`.env` to the host's IP (or `0.0.0.0`); see
[`docs/configuration.md#ports-and-exposure`](docs/configuration.md#ports-and-exposure).
There is no authentication, so keep the MCP port on loopback.

### Without cloning the repo

```bash
mkdir -p data/{models,input,output,custom_nodes,user}

docker run -d --name comfyui-agent-stack --gpus all --restart unless-stopped \
  -e PUID="$(id -u)" -e PGID="$(id -g)" \
  -p 127.0.0.1:8188:8188 -p 127.0.0.1:8080:8080 \
  -v "$PWD/data/models:/opt/ComfyUI/models" \
  -v "$PWD/data/input:/opt/ComfyUI/input" \
  -v "$PWD/data/output:/opt/ComfyUI/output" \
  -v "$PWD/data/custom_nodes:/opt/ComfyUI/custom_nodes" \
  -v "$PWD/data/user:/opt/ComfyUI/user" \
  ghcr.io/staypirate/comfyui-agent-stack:latest
```

## Connect an agent (opencode)

Add the server to `~/.config/opencode/opencode.json` (see
[`examples/opencode.jsonc`](examples/opencode.jsonc)):

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

Restart the client, then try:

> Check that my local ComfyUI is running, find a text-to-image template, run it
> with the prompt "a fox in a snowy forest", and show me the result.

[`AGENTS.md`](AGENTS.md) describes the intended workflow in detail.

## Storage

| Host path                       | Container path                | Purpose                   |
| ------------------------------- | ----------------------------- | ------------------------- |
| `data/models/`                  | `/opt/ComfyUI/models`         | checkpoints, LoRAs, VAE…  |
| `data/input/`                   | `/opt/ComfyUI/input`          | source images/masks       |
| `data/output/`                  | `/opt/ComfyUI/output`         | generated assets          |
| `data/custom_nodes/`            | `/opt/ComfyUI/custom_nodes`   | installed node packs      |
| `data/user/`                    | `/opt/ComfyUI/user`           | settings, logs            |
| `config/extra_model_paths.yaml` | `/opt/ComfyUI/extra_model_paths.yaml` | extra model paths |

## Documentation

| Document                                   | Contents                                  |
| ------------------------------------------ | ----------------------------------------- |
| [`docs/configuration.md`](docs/configuration.md) | Env vars, GPU flags, security        |
| [`docs/publishing.md`](docs/publishing.md) | CI, GHCR, version pinning, Renovate       |
| [`docs/architecture.md`](docs/architecture.md) | How the pieces fit together            |
| [`docs/custom-nodes.md`](docs/custom-nodes.md) | Baseline vs. on-demand node packs      |
| [`docs/nvidia-arch.md`](docs/nvidia-arch.md) | NVIDIA Container Toolkit on Arch Linux |
| [`docs/troubleshooting.md`](docs/troubleshooting.md) | Common issues                    |
| [`AGENTS.md`](AGENTS.md)                   | How agents should drive the stack         |

## License

This repository is MIT-licensed ([`LICENSE`](LICENSE)). The image bundles
third-party software under its own terms — notably ComfyUI (GPL-3.0) and
comfy-mcp (AGPL-3.0-or-later OR commercial). See
[`THIRD_PARTY_LICENSES.md`](THIRD_PARTY_LICENSES.md). Models are never
redistributed.