#!/usr/bin/env bash
set -euo pipefail

if ! command -v lnav >&/dev/null; then
  echo "[ERROR] lnav is not installed" >&2
  exit 1
fi

echo "Starting lnav, watching kernel logs"
echo "[WARNING] Kernel logs require sudo permissions"

sudo lnav /var/log/kern.log

