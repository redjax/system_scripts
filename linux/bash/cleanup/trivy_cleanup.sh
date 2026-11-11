#!/usr/bin/env bash
set -euo pipefail

if ! command -v trivy >/dev/null 2>&1; then
  echo "[ERROR] Trivy is not installed" >&2
  exit 1
fi

echo "Running Trivy's cleanup"
if ! trivy clean --all 2>&1; then
  echo "[ERROR] Failed during Trivy's cleanup" >&2
  exit 1
fi

echo
echo "Trivy cleanup complete"

