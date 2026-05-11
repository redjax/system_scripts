#!/usr/bin/env bash
set -euo pipefail

DEST="$1"

echo "[CHECK] $DEST"

git -C "$DEST" fsck --full
git -C "$DEST" gc --auto
