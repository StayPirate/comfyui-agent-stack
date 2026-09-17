# Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│ Host (e.g. Arch Linux + NVIDIA driver + container toolkit)          │
│                                                                     │
│  opencode / Claude / Cursor                                          │
│      │  Streamable HTTP  http://127.0.0.1:8080/mcp                   │
│      ▼                                                               │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │ docker container: comfyui-agent-stack                          │  │
│  │                                                                │  │
│  │  supergateway :8080  ──stdio──►  comfy-mcp                     │  │
│  │                                     │                          │  │
│  │                                     │ comfy-cli (--where local)│  │
│  │                                     ▼                          │  │
│  │                                  comfy  ──►  ComfyUI :8188     │  │
│  │                                                                │  │
│  │  tini (PID 1) ─ entrypoint.sh ─ watchdog                       │  │
│  └───────────────────────────────┬────────────────────────────────┘  │
│                                  │ bind mounts                       │
│      ./data/{models,input,output,custom_nodes,user}, ./config        │
└─────────────────────────────────────────────────────────────────────┘
```

## Why these components

**comfy-mcp (official, first-party).** The maintained local MCP server from
Comfy-Org. It wraps `comfy-cli` and exposes ~40 tools: generation, job
management, live node/model introspection, templates, logs and lifecycle.

**supergateway.** comfy-mcp speaks **stdio** only, which forces MCP clients to
launch it as a local subprocess. Running it inside the container and bridging it
to **Streamable HTTP** means an agent connects with a plain URL — no `docker
exec`, no co-located install, and the container can start independently of the
client.

**comfy-cli as the engine.** Every MCP tool shells out to
`comfy --where local --json`. This is why `comfy-cli` and the ComfyUI workspace
must live in the same container as the MCP server: filesystem tools (models,
custom nodes, outputs, logs) operate on the container's paths.

**A seed directory for baseline nodes.** `custom_nodes` is bind-mounted from
`./data`, which would hide anything baked into the image. Instead the image
keeps baseline packs in `/opt/comfy-baseline/custom_nodes` and the entrypoint
copies them in with `cp -rn` (no-clobber), so user-installed packs are never
overwritten.

## Startup sequence

1. `tini` becomes PID 1 (signal handling, reaping).
2. `entrypoint.sh` remaps the `comfy` user to `PUID:PGID`.
3. Data dirs are created and chowned; baseline nodes are seeded.
4. `comfy set-default /opt/ComfyUI` registers the workspace.
5. `comfy launch --background` starts ComfyUI (background launch keeps a log at
   `user/comfyui_<port>.log`, which the MCP `get_logs` tool reads).
6. The entrypoint polls `/system_stats` until the API answers.
7. A watchdog exits the container if ComfyUI stops answering, so `restart:
   unless-stopped` brings it back.
8. `supergateway` exposes `comfy-mcp` over Streamable HTTP and becomes the
   foreground process.

## Trade-offs

- **Statefulness.** The MCP bridge defaults to stateful sessions for maximum
  client compatibility. Set `MCP_STATEFUL=false` if your client diverges.
- **Concurrency.** Multiple agents can talk to the same endpoint, but ComfyUI
  has a single GPU queue: jobs serialize. Use job tools rather than assuming
  parallelism.
- **Single-user.** There is no auth; keep the ports on loopback.
