#!/usr/bin/env bash

set -uo pipefail

if ! command -v curl &>/dev/null; then
  echo "[ERROR] curl is not installed."
  exit 1
fi

echo "Downloading intelli-shell"

curl -sSf https://raw.githubusercontent.com/lasantosr/intelli-shell/main/install.sh | sh
if [[ $? -ne 0 ]]; then
  echo "[ERROR] Failed to install intelli-shell"
  exit $?
else
  echo "Intelli-shell installed."
  echo "Press CTRL+Space to begin using it"

  exit 0
fi
