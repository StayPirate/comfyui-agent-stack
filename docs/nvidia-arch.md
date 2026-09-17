# NVIDIA Container Toolkit on Arch Linux

Docker needs the **NVIDIA Container Toolkit** to expose your GPU to containers.
On Arch it is packaged in the official `extra` repository — no AUR needed.

## 1. Install the driver and toolkit

```bash
sudo pacman -Syu
sudo pacman -S nvidia nvidia-utils nvidia-container-toolkit
```

- `nvidia` / `nvidia-utils` — the proprietary driver (or `nvidia-open` for
  Turing+ cards).
- `nvidia-container-toolkit` — pulls in `libnvidia-container` and provides
  `nvidia-ctk`.

Reboot after a driver (re)install:

```bash
sudo reboot
```

Verify the driver sees the GPU:

```bash
nvidia-smi
```

## 2. Register the toolkit with Docker

```bash
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

This adds the `nvidia` runtime to `/etc/docker/daemon.json`. Confirm with:

```bash
docker info | grep -i runtime
```

## 3. Test GPU access

```bash
docker run --rm --gpus all nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi
```

If `nvidia-smi` prints your GPU, the toolkit works. Inside this stack:

```bash
docker compose exec comfyui nvidia-smi
```

and the MCP `system_stats` tool should report your GPU and VRAM.

## Troubleshooting

- **`could not select device driver "nvidia" with capabilities: [[gpu]]`**
  The toolkit is not registered with the active runtime. Re-run
  `nvidia-ctk runtime configure --runtime=docker` and restart Docker.
- **`nvidia-container-cli: initialization error: nvml error`**
  Driver/library mismatch. Update `nvidia`, `nvidia-utils` and
  `nvidia-container-toolkit` together and reboot.
- **cgroup v2 / rootless Docker**: rootless mode with GPU is limited. Use
  rootful Docker, or rootlesskit ≥ 1.1 with cgroup delegation.
- **Pacman upgraded the driver while the stack was running**: restart the
  container (`docker compose restart`) so it picks up the new host libraries.

## Podman

Podman works too:

```bash
sudo nvidia-ctk runtime configure --runtime=podman
```

Then use `podman compose` (or `podman-compose`) in place of `docker compose`.
