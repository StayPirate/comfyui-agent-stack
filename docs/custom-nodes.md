# Custom nodes: baseline vs. on-demand

The stack uses a two-tier strategy so that the image stays buildable and the
first run is not a wall of missing-node errors.

## Tier 0 — ComfyUI-Manager (pip, always present)

Manager is **not** a custom-node clone anymore. ComfyUI ships its pinned version
in `manager_requirements.txt`, which the image installs as a pip package
(`comfyui_manager` / `cm-cli`); `comfy launch` then injects `--enable-manager`.
This is what powers `comfy-cli`'s node install/update commands.

A git-cloned Manager under `custom_nodes/` is deliberately blocked by policy in
that mode, so the baseline no longer seeds one. If an older volume still has
`custom_nodes/ComfyUI-Manager`, the entrypoint moves it to
`custom_nodes/.disabled/` on startup.

## Tier 1 — baseline (baked, seeded on first start)

Defined in [`docker/baseline-nodes.txt`](../docker/baseline-nodes.txt). The
entrypoint copies these into `./data/custom_nodes` with `cp -rn`, so they appear
on first start and are **never** overwritten afterwards. The default set:

| Pack                          | Why it is included                |
| ----------------------------- | --------------------------------- |
| ComfyUI-VideoHelperSuite      | video/image sequence IO           |
| rgthree-comfy                 | widely-used workflow utilities    |
| ComfyUI-Custom-Scripts        | general quality-of-life nodes     |

Edit the file to change the baseline, then rebuild. Pin a ref per line
(`<git-url> <ref>`) for reproducibility.

## Tier 2 — on-demand (installed by the agent)

Workflow-specific packs — LTX/WAN for video, ACE-Step/Stable Audio for music,
ControlNet helpers, and so on — are **not** baked in. They change frequently and
would bloat the image. The agent installs them when a workflow needs them, via
`comfy-cli`/ComfyUI-Manager, then restarts ComfyUI.

Typical agent flow:

```
validate_workflow  → missing node types reported
install_node       → fetch the pack
restart_comfyui    → load it
validate_workflow  → clean
run_workflow
```

## Why not bake everything?

- Reproducible build: a failing third-party dependency at build time breaks the
  whole image.
- Freshness: agents install the current version of a pack when needed.
- Size: many packs pull large dependencies that most users never use.

## System libraries vs. Python packages

The split that keeps the image useful without bloating it:

- **System libraries (apt) are baked in.** They cannot be installed durably at
  runtime — an agent's `apt-get install` lands in the container's writable layer
  and is lost on the next rebuild — so the common ones for image/video/audio
  packs ship in the image: `portaudio19-dev`, `libsndfile1-dev`,
  `libsamplerate0-dev`, `fluidsynth`/`libfluidsynth-dev`, `sox`/`libsox-fmt-all`
  and `libsm6`, alongside `ffmpeg`.
- **Python packages are left to the node packs.** Each pack declares its own
  `requirements.txt`/`pyproject.toml`; with Manager working, `install_node`
  installs them. Baking a broad Python set would duplicate those and risk
  pinning conflicts with the PyTorch/numpy stack.

So if a pack needs `pyaudio`, `soundfile` or `pretty_midi`, its `pip install`
succeeds against the baked system headers instead of failing on a missing
`portaudio.h`. The Python package itself is still installed on demand.

## Manual management

```bash
# inside the container
docker compose exec comfyui bash -lc 'comfy node install <registry-id>'
docker compose exec comfyui bash -lc 'comfy node show installed'

# or through the web UI: Manager → Custom Nodes Manager
```

Installed packs land in `./data/custom_nodes` and survive rebuilds. Node
dependencies installed with `pip` live in the image's virtualenv, so a
dependency added by a node pack can be lost on rebuild — if a pack stops
importing after a rebuild, reinstall/repair it through Manager.
