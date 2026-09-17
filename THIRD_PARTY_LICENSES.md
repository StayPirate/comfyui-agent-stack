# Third-party licenses

This repository's own code and documentation are licensed under the **MIT
License** (see [`LICENSE`](LICENSE)).

The **container image** built from this repository bundles third-party software
under its own terms. This file is a non-exhaustive summary, not legal advice —
review the upstream licenses before redistributing the image.

| Component          | License                                   | Upstream |
| ------------------ | ----------------------------------------- | -------- |
| ComfyUI            | GPL-3.0                                    | https://github.com/comfyanonymous/ComfyUI |
| ComfyUI-Manager    | GPL-3.0                                    | https://github.com/ltdrdata/ComfyUI-Manager |
| comfy-cli          | see repository                             | https://github.com/Comfy-Org/comfy-cli |
| comfy-mcp          | AGPL-3.0-or-later OR Commercial            | https://github.com/Comfy-Org/comfy-mcp |
| supergateway       | MIT                                        | https://github.com/supercorp-ai/supergateway |
| PyTorch            | BSD-3-Clause                               | https://github.com/pytorch/pytorch |
| NVIDIA CUDA base   | NVIDIA Software License                    | https://www.nvidia.com/en-us/drivers/ |
| FFmpeg             | LGPL/GPL (build-dependent)                 | https://ffmpeg.org/legal.html |
| Additional custom nodes | per upstream repository               | see `docker/baseline-nodes.txt` |

## Copyleft considerations

- ComfyUI is **GPL-3.0** and comfy-mcp is **AGPL-3.0-or-later** (or a commercial
  license from Comfy-Org). Distributing a container image that includes them is
  permitted, but you must comply with their source-availability and notice
  obligations. If in doubt, distribute this repository (which builds the image)
  rather than only a binary image, and keep the corresponding sources reachable.
- If you need to embed Comfy technologies in a proprietary product, review the
  commercial options offered by Comfy-Org.

## Models are not redistributed

No model weights are included in this repository or image. Downloaded models
carry their own licenses (often non-commercial or use-restricted). You are
responsible for complying with them.
