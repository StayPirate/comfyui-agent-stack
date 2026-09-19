# Troubleshooting

## The container starts but ComfyUI never becomes ready

```bash
docker compose logs --tail=200 comfyui
docker compose exec comfyui bash -lc 'tail -n 200 ./user/comfyui_8188.log'
```

Common causes:

- **GPU not visible.** `docker compose exec comfyui nvidia-smi` must print your
  card. If not, fix the NVIDIA Container Toolkit — see
  [`nvidia-arch.md`](nvidia-arch.md).
- **Out of VRAM at startup.** Add `--lowvram` (or `--novram`) to `COMFYUI_ARGS`
  in `.env` and `docker compose up -d`.
- **A bad custom node** left in `./data/custom_nodes`. Disable or remove it:
  `docker compose exec comfyui bash -lc 'comfy node disable <name>'`.

## The agent cannot see the MCP tools

1. Confirm the endpoint answers: `curl -i http://127.0.0.1:8080/mcp` (a
   protocol error response is expected; a connection refusal is not).
2. Check `docker compose ps` shows the container as healthy.
3. With stateful sessions, some clients need `MCP_STATEFUL=false`. Toggle it in
   `.env` and restart.
4. Restart the agent client after changing its MCP config.
5. Verify the bridge is actually listening inside the container:

   ```bash
   docker compose exec comfyui ss -ltnp | grep 8080
   ```

   If it only listens on `127.0.0.1` inside the container, the host port
   mapping cannot reach it — report it, since the bridge is expected on
   `0.0.0.0`.

6. **After recreating the container** (`docker compose up -d` following a change
   to ports, env, or image) any MCP session the client had opened is
   invalidated — the bridge keeps no session state across a restart and the
   client may not re-initialize mid-session. Calls then fail with
   `No valid session ID provided`. Restart the agent client. The endpoint itself
   is fine; confirm with a fresh handshake:

   ```bash
   curl -si -X POST http://127.0.0.1:8080/mcp \
     -H 'Content-Type: application/json' \
     -H 'Accept: application/json, text/event-stream' \
     -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"probe","version":"0"}}}'
   ```

   A `200` with an `mcp-session-id` response header means the endpoint is
   healthy.

## Node install fails / Manager is not available

The image installs ComfyUI-Manager as a **pip package** (from ComfyUI's
`manager_requirements.txt`) and `comfy launch` enables it with
`--enable-manager`. Verify it inside the container:

```bash
docker compose exec comfyui bash -lc 'PYTHONPATH=/opt/ComfyUI python -c "import comfyui_manager, cm_cli; print(\"manager ok\")"'
```

If that fails, the image was built from a ComfyUI ref without
`manager_requirements.txt`, or the pip install did not run — rebuild the image.
A git-cloned `ComfyUI-Manager` under `custom_nodes/` is **not** the active
Manager and is blocked by policy; the entrypoint moves it to
`custom_nodes/.disabled/`. Seeing `Blocked by policy: .../ComfyUI-Manager` in
the log is therefore expected for an old volume until it is retired.

If Manager is present but installing a node fails with `Failed to create
directory /opt/venv/...: Permission denied`, the runtime user does not own the
virtualenv. The image builds the venv as the default runtime user (`uid 1000`),
so this happens when `PUID` is set to something else. Either set `PUID=1000` in
`.env` and recreate the container, or install the node as root:

```bash
docker compose exec comfyui bash -lc 'comfy node install <registry-id>'
```

## "Missing model" when running a workflow

Expected on a model-free image. Ask the agent to download it:

```
validate_workflow reported missing models — download what the workflow needs
and run it again
```

Or seed manually with `models.manifest.txt` + `make bootstrap`.

## Permission denied on files in ./data

The container runs as `PUID:PGID`. Set them in `.env` to your host user
(`id -u` / `id -g`) and restart:

```bash
docker compose down && docker compose up -d
```

Existing files may need a one-time fix on the host:

```bash
sudo chown -R "$(id -u):$(id -g)" data
```

## Partner nodes fail with `partner_node_requires_credential`

Set a Comfy API key: uncomment the `COMFY_API_KEY` mapping in `compose.yaml`,
put the key in `.env`, and restart. You can also sign in with
`docker compose exec comfyui bash -lc 'comfy cloud login'` (browser OAuth).

## Generation is extremely slow

- You may be on the CPU profile. Check `nvidia-smi` inside the container.
- Video/audio models are heavy. On 8–24 GB cards, prefer smaller models and
  image work; consider partner-API nodes for video.
- Free VRAM before heavy runs: MCP `free_memory`, or stop other GPU users.

## Rebuilding lost an installed package

Node dependencies installed by packs live in the image venv, not in `./data`.
After a rebuild, reinstall the affected pack through Manager or run
`comfy node reinstall <name>`.

System libraries (apt) are different: the common image/video/audio ones
(`portaudio19-dev`, `libsndfile1-dev`, `fluidsynth`, `sox`, …) are baked into
the image. An `apt-get install` you run inside a container does **not** survive
a rebuild — if a pack needs a system package that is not in the image, add it to
`docker/Dockerfile` and rebuild rather than installing it by hand.
