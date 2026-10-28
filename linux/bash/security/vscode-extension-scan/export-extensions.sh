#!/usr/bin/env bash
set -euo pipefail

OUT="${1:-./vscode-audit}"
EXT_DIR="${VSCODE_EXTENSIONS_DIR:-$HOME/.vscode/extensions}"

THIS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

CWD="$(pwd)"
trap 'cd "${CWD}"' EXIT

cd "${THIS_DIR}"

mkdir -p "$OUT"

if ! command -v code >/dev/null 2>&1; then
  echo "[ERROR] 'code' CLI not found in PATH." >&2
  exit 1
fi

if [[ ! -d "$EXT_DIR" ]]; then
  echo "[ERROR] Extension directory not found: $EXT_DIR" >&2
  echo "Set VSCODE_EXTENSIONS_DIR to your VS Code extensions path." >&2
  exit 1
fi

echo "[INFO] Exporting extension inventory"
code --list-extensions --show-versions \
  | sort > "$OUT/extensions.txt"

echo "[INFO] Recording installed extension files"
printf '%s\n' "$EXT_DIR" > "$OUT/extensions-path.txt"

echo "[INFO] Inventory saved to: $OUT/extensions.txt"
echo "[INFO] Extension directory: $EXT_DIR"
echo "[INFO] Done."

