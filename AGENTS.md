# AGENTS.md — Operating the ComfyUI Agent Stack

This document tells an AI agent how to drive the ComfyUI instance exposed by
this stack through the `comfyui` MCP server (`http://127.0.0.1:8080/mcp`).

## Mental model

- ComfyUI runs **inside a container**; the MCP server (`comfy-mcp`) runs there
  too and shells out to `comfy-cli`. Tools that touch the filesystem (models,
  input, output, custom nodes, logs) operate on the **container's** paths — which
  are bind-mounted from `./data` on the host.
- Prefer the official **workflow templates** before building graphs from scratch.
- The stack starts **model-free**: expect to install models and node packs on
  first use. This is normal, not an error.

## Standard workflow

1. **Confirm the backend is up** — call `server_info` first.
2. **Discover a template** — `search_templates` (by text/tag/media type), then
   `fetch_template` to get runnable JSON.
3. **Check requirements** — `validate_workflow` against the live install;
   `search_nodes` / `get_node` for node specs; `search_models` for what is on disk.
4. **Fill dependencies**
   - Missing node packs: install via comfy-cli/Manager (`install_node`), then
     `restart_comfyui`.
   - Missing models: `download_model` (or `comfy model download`) into the right
     `models/<type>/` folder.
5. **Run** — `run_workflow` (`wait=False` for long jobs, then `job`/`wait_for_job`).
6. **Collect outputs** — `fetch_outputs(prompt_id, out_dir)`; the UI-facing copy
   is already in `./data/output` on the host. Use `view_image` when you need to
   *see* the result and iterate.
7. **Iterate** — adjust prompt/params, or use `regenerate` to replay with
   overrides.

## Rules of thumb

- **Long generations**: submit with `wait=False`, poll with `job(action="status")`,
  and never leave a job orphaned — `job(action="cancel")` if the user changes
  their mind.
- **VRAM**: call `system_stats` before heavy runs. On cards under 24 GB, prefer
  smaller/current models and expect video to be slow. `free_memory` unloads
  ComfyUI's models when needed.
- **Costs**: partner-API nodes (`partner_generate`, or API-tagged templates)
  spend credits on Comfy's infrastructure. Ask the user before using them.
- **Node installs run third-party code.** Keep node packs pinned where possible,
  and prefer the ComfyUI Registry.
- **Do not invent model URLs.** Resolve them through `search_models`,
  Hugging Face search, or the user.
- **Images to inspect**: save them under `./data/output` (or pass an absolute
  container path) so `view_image` can read them.

## Useful starting points (examples, not guarantees)

| Goal            | Suggested template tags / media type      |
| --------------- | ----------------------------------------- |
| Image           | `Text to Image`                           |
| Image edit      | `Image Edit`, `Inpaint`, `Upscale`        |
| Video           | `Text to Video`, `Image to Video`         |
| Audio / music   | audio templates (ACE-Step, Stable Audio)  |

Always verify against `search_templates` — the gallery tracks current models.

## Filesystem map (container paths)

| Path                  | Contents                          |
| --------------------- | --------------------------------- |
| `/opt/ComfyUI/models` | checkpoints, loras, vae, unet, …  |
| `/opt/ComfyUI/input`  | source images uploaded for jobs   |
| `/opt/ComfyUI/output` | generated assets                  |
| `/opt/ComfyUI/user`   | settings and `comfyui_<port>.log` |

## When something fails

- Read `server_info`'s `freshness` block and `get_logs` (the log lives at
  `<workspace>/user/comfyui_<port>.log`).
- `get_history` / `diagnose` explain failed runs (failing node, missing models,
  missing node types).
- If the MCP endpoint does not answer, the container is down — ask the user to
  run `make logs` / `docker compose up -d`.
