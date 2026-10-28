#!/usr/bin/env bash
set -euo pipefail

IMG="vsix-scan:local"

OUT="${1:-}"
EXT_DIR="${VSCODE_EXTENSIONS_DIR:-$HOME/.vscode/extensions}"

THIS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

CWD="$(pwd)"
trap 'cd "${CWD}"' EXIT

if [[ -z "${OUT}" ]]; then
  OUT="${THIS_DIR}/vscode-audit"
fi

cd "${THIS_DIR}"

mkdir -p "$OUT"
mkdir -p "$OUT/cache"

if ! docker image inspect "$IMG" >/dev/null 2>&1; then
  echo "[ERROR] Image not found: $IMG" >&2
  echo "Run ./build-container.sh first." >&2
  exit 1
fi

if [[ ! -d "$EXT_DIR" ]]; then
  echo "[ERROR] Extension directory not found: $EXT_DIR" >&2
  exit 1
fi

echo "[INFO] Scanning extensions from: $EXT_DIR"
echo "[INFO] Writing report to: $OUT/report.json"

docker run --rm \
  --read-only \
  --cap-drop=ALL \
  --security-opt=no-new-privileges \
  --tmpfs /tmp:rw,noexec,nosuid,size=64m \
  -e HOME=/tmp \
  -v "$EXT_DIR:/tmp/.vscode/extensions:ro" \
  -v "$OUT/cache:/tmp/.vsix-scan/cache" \
  "$IMG" \
  scan-all --format json \
  2> >(tee "$OUT/scan.log" >&2) \
  | tee "$OUT/report.json"

echo "[INFO] Scan finished."
echo "[INFO] Report saved to: $OUT/report.json"

