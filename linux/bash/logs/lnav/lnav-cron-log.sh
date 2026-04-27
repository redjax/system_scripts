#!/usr/bin/env bash
set -euo pipefail

if ! command -v lnav >&/dev/null; then
  echo "[ERROR] lnav is not installed" >&2
  exit 1
fi

echo "Starting lnav, watching cron log"
echo "[WARNING] cron logs require sudo permissions"

sudo journalctl -u cron | lnav

