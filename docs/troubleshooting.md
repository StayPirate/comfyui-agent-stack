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
