#!/bin/bash

if ! command -v curl >/dev/null 2>&1; then
  echo "[ERROR] curl is not installed"
  exit 1
fi

echo "Downloading Go installer & executing with Bash"
bash <(curl -sL https://git.io/go-installer)
if [[ $? -ne 0 ]]; then
  echo "[ERROR] Failed to install Go."
  exit 1
fi

