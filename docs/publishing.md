# Building and publishing

## Automated builds

[`../.github/workflows/build-push.yml`](../.github/workflows/build-push.yml)
builds `linux/amd64` and pushes to `ghcr.io/<owner>/<repo>` on:

- every push to `main` (tags `main`, `latest`, `sha-<commit>`),
- `v*` tags (adds semver tags),
- pull requests (build only, no push),
- a **weekly schedule** (Monday night, Europe/Rome),
- manual `workflow_dispatch`.

Images carry **SBOM** and **provenance** attestations
(`provenance: true`, `sbom: true`). A weekly
[Trivy scan](../.github/workflows/trivy.yml) reports vulnerabilities to GitHub
Security.

### Manual rebuild with version overrides

The `workflow_dispatch` event accepts:

- `comfyui_ref` — any branch/tag/commit for ComfyUI.
- `cuda_version` — the CUDA base image version (default `12.6.3`).

## Consuming the published image

```bash
# .env
COMFYUI_IMAGE=ghcr.io/<owner>/comfyui-agent-stack:latest
```

```bash
docker compose pull && docker compose up -d
```

Make the package public in the repository's *Packages* settings for anonymous
pulls.

## Building locally

```bash
docker compose build

# Pin versions (all of these are ARGs at the top of docker/Dockerfile)
docker compose build \
  --build-arg COMFYUI_REF=v0.36.0 \
  --build-arg TORCH_VERSION=2.11.0
```

Every version in `docker/Dockerfile` is an `ARG` with a `# renovate:`
annotation. [Renovate](https://docs.renovatebot.com/) (see
[`../renovate.json`](../renovate.json)) keeps base image, GitHub Actions,
ComfyUI, comfy-cli, comfy-mcp, the PyTorch trio and supergateway up to date.

The PyTorch trio is grouped and requires dashboard approval: `torch`,
`torchvision` and `torchaudio` must move together. The image build imports all
three, so an incompatible bump fails the pull request before publication.