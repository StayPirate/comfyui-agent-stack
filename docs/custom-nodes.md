# Custom nodes: baseline vs. on-demand

The stack uses a two-tier strategy so that the image stays buildable and the
first run is not a wall of missing-node errors.

## Tier 1 — baseline (baked, seeded on first start)

Defined in [`docker/baseline-nodes.txt`](../docker/baseline-nodes.txt). The
entrypoint copies these into `./data/custom_nodes` with `cp -rn`, so they appear
on first start and are **never** overwritten afterwards. The default set:

| Pack                          | Why it is included                |
| ----------------------------- | --------------------------------- |
| ComfyUI-Manager               | runtime node install/update       |
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
