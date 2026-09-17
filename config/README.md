# config/

Files here are bind-mounted into the container.

| File                     | Mounted at                              | Notes |
| ------------------------ | --------------------------------------- | ----- |
| `extra_model_paths.yaml` | `/opt/ComfyUI/extra_model_paths.yaml`   | Read-only. Empty by default; add blocks to expose host model libraries. |

Mount additional host paths (for example an external model library referenced
from `extra_model_paths.yaml`) by editing the `volumes:` list in
[`../compose.yaml`](../compose.yaml).
