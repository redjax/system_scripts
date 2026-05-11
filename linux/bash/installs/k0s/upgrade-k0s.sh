#!/usr/bin/env bash

set -uo pipefail

if ! command -v k0s &>/dev/null; then
  echo "[ERROR] k0s is not installed."

  exit 1
fi

echo ""
echo "[ Upgrade k0s ]"
echo ""

echo "Stopping k0s"
if ! sudo k0s stop; then
  echo ""
  echo "[ERROR] Failed stopping k0s"

  while true; do

    read -n 1 -r -p "Proceed anyway? (y/n) " yn

    case $yn in
        [Yy]*)
        echo ""
        break
        ;;
        [Nn]*)
        echo "Exiting"
        exit 1
        ;;
        *)
        echo "[ERROR] Invalid choice '$yn'. Please use 'y' or 'n'"
        echo ""
        ;;
    esac
  done
fi

echo "Downloading update"
curl -sSLf https://get.k0s.sh | sudo sh
if [[ $? -ne 0 ]]; then
  echo "[ERROR] Failed to download & install k0s update."
  exit 1
fi

echo "Starting k0s"
sudo k0s start
if [[ $? -ne 0 ]]; then
  echo "[ERROR] Failed to start k0s"
  exit 1
fi

