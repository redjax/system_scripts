#!/usr/bin/env bash

if ! command -v curl &>/dev/null; then
  echo "[ERROR] curl is not installed."
  exit 1
fi

echo ""
echo "Installing SuperFile"
echo ""

if ! bash -c "$(curl -sLo- https://superfile.dev/install.sh)"; then
  echo "[ERROR] Failed to install SuperFile"
  exit $?
else
  echo "SuperFile installed"
  exit 0
fi
