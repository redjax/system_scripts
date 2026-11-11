#!/usr/bin/env bash
set -euo pipefail

if ! command -v mise >/dev/null 2>&1; then
  echo "[ERROR] Mise is not installed" >&2
  exit 1
fi

echo "Running Mise's cleanup"
if ! mise prune 2>&1; then
  echo "[ERROR] Failed during Mise's cleanup" >&2
  exit 1
fi

echo
echo "Mise cleanup complete"

