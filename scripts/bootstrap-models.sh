#!/usr/bin/env bash
# Download the models listed in models.manifest.txt into ./data/models.
# Run it on the host (or inside the container against a mounted data dir).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="${1:-${ROOT}/models.manifest.txt}"
MODELS_DIR="${ROOT}/data/models"

[ -f "${MANIFEST}" ] || { echo "manifest not found: ${MANIFEST}" >&2; exit 1; }

downloader="curl"
command -v aria2c >/dev/null 2>&1 && downloader="aria2c"

count=0
while IFS='|' read -r type url filename; do
  # Trim whitespace and skip blanks/comments.
  type="$(echo "${type:-}" | xargs || true)"
  url="$(echo "${url:-}" | xargs || true)"
  filename="$(echo "${filename:-}" | xargs || true)"
  [ -z "${type}" ] && continue
  case "${type}" in \#*) continue ;; esac
  if [ -z "${url}" ] || [ -z "${filename}" ]; then
    echo "skipping malformed line for type '${type}'" >&2
    continue
  fi

  dest_dir="${MODELS_DIR}/${type}"
  mkdir -p "${dest_dir}"
  if [ -f "${dest_dir}/${filename}" ]; then
    echo "already present: ${type}/${filename}"
    continue
  fi

  echo "downloading ${type}/${filename}"
  if [ "${downloader}" = "aria2c" ]; then
    aria2c --dir="${dest_dir}" --out="${filename}" --continue=true "${url}"
  else
    curl -fL --retry 3 --continue-at - -o "${dest_dir}/${filename}" "${url}"
  fi
  count=$((count + 1))
done < "${MANIFEST}"

echo "done (${count} downloaded)"
