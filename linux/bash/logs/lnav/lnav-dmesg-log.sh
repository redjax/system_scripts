#!/usr/bin/env bash
set -euo pipefail

if ! command -v lnav >&/dev/null; then
  echo "[ERROR] lnav is not installed" >&2
  exit 1
fi

echo "Starting lnav, watching dmesg"
echo "[WARNING] dmesg logs require sudo permissions"

sudo dmesg -x | lnav

