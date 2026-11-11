#!/usr/bin/env bash
set -euo pipefail

if ! command -v uv >/dev/null 2>&1; then
  echo "[ERROR] Uv is not installed" >&2
  exit 1
fi

echo "Running Uv's cleanup"
if ! uv cache prune 2>&1; then
  echo "[ERROR] Failed during Uv's cleanup" >&2
  exit 1
fi

echo
echo "Uv cleanup complete"

