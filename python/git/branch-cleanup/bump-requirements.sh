#!/usr/bin/env bash
set -euo pipefail

THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CWD="$(pwd)"
trap 'cd "$CWD"' EXIT

cd "$THIS_DIR"

if ! command -v uv >/dev/null 2>&1; then
  echo "[ERROR] uv is not installed" >&2
  exit 1
fi

echo "Recompiling requirements.txt with uv"
uv pip compile requirements.txt -o requirements.txt --upgrade
uv pip sync requirements.txt
