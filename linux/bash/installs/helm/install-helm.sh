#!/usr/bin/env bash

set -uo pipefail

if ! command -v curl &>/dev/null; then
  echo "[ERROR] curl is not installed."
  exit 1
fi

echo "Installing Helm"

curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
if [[ $? -ne 0 ]]; then
  echo "[ERROR] Failed installing Helm."
  exit $?
else
  echo "Helm installed."
  exit 0
fi

