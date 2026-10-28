#!/usr/bin/env bash
set -euo pipefail

IMG="vsix-scan"
TAG="local"

THIS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

CWD="$(pwd)"
trap 'cd "${CWD}"' EXIT

cd "${THIS_DIR}"

echo "Building container: ${IMG}:${TAG}"

if ! docker build -t "${IMG}:${TAG}" . 2>&1; then
  echo "[ERROR] Failed building container" >&2
  exit 1
fi

