# Building and publishing

## Automated builds

[`../.github/workflows/build-push.yml`](../.github/workflows/build-push.yml)
builds `linux/amd64` and pushes to `ghcr.io/<owner>/<repo>` on:

- every push to `main` (tags `main`, `latest`, `sha-<commit>`),
- `v*` tags (adds semver tags and creates a GitHub Release),
- pull requests (build only, no push),
- a **weekly schedule** (Monday night, Europe/Rome),
- manual `workflow_dispatch`.

Images carry **SBOM** and **provenance** attestations
(`provenance: true`, `sbom: true`). A weekly
[Trivy scan](../.github/workflows/trivy.yml) reports vulnerabilities to GitHub
Security. Every pushed tag also gets a GitHub Release with auto-generated
notes (see [Versioning](#versioning)).

### Manual rebuild with version overrides

The `workflow_dispatch` event accepts:

- `comfyui_ref` — any branch/tag/commit for ComfyUI.
- `cuda_version` — the CUDA base image version (default `12.6.3`).

## Versioning

The project follows [Semantic Versioning](https://semver.org/) `vMAJOR.MINOR.PATCH`
on the **stack's own contract**, not on the bundled upstream versions. Starting
point is `v0.1.0`.

| Bump      | When                                                                                         |
| --------- | -------------------------------------------------------------------------------------------- |
| **MAJOR** | A change breaks consumers: renamed env vars, volume/port layout, dropped baseline node packs, a CUDA base major, compose contract changes. |
| **MINOR** | Additive features or compatible upstream bumps (ComfyUI, comfy-cli, comfy-mcp, PyTorch).     |
| **PATCH** | Fixes, security rebuilds and other changes with no usage impact.                              |

Upstream component versions are **not** encoded in the project version. They are
recorded as OCI labels on the image (`org.opencontainers.image.version` /
`.revision`, plus `io.github.staypirate.comfyui-agent-stack.*`), so
`docker inspect` reveals what a given release bundles and from which commit it
was built.

Tag channels produced by CI:

- `:0.1.0` — immutable, one per release.
- `:0.1` — floats over patch releases of the `0.1` line.
- `:latest` — **rolling `main`**, not the latest release. Do not use it in
  production.
- `:main`, `:sha-<commit>` — branch/commit builds.

A floating `:0` (major) tag is intentionally omitted until `v1.0.0`, since
during `0.x` a minor bump may be breaking.

### Cutting a release

Tag `main` and push; CI builds the image, pushes the semver tags and creates the
GitHub Release with generated notes:

```bash
git tag -a v0.1.0 -m "v0.1.0"
git push origin v0.1.0
```

## Consuming the published image

```bash
# .env — pin a release for reproducibility
COMFYUI_IMAGE=ghcr.io/<owner>/comfyui-agent-stack:0.1.0
```

```bash
docker compose pull && docker compose up -d
```

For maximum reproducibility pin by digest
(`ghcr.io/<owner>/comfyui-agent-stack@sha256:…`); Renovate can keep that pin
updated. Avoid `:latest` (rolling `main`) outside local testing.

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