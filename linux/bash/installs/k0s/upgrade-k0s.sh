#!/usr/bin/env bash
set -euo pipefail

########################################
# k0s upgrader
########################################

KUBECONFIG_PATH="${HOME}/.kube/config"

function require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "[ERROR] Missing required command: $1"
    exit 1
  }
}

function prompt_yes_no() {
  local prompt="$1"

  while true; do
    read -rp "${prompt} (y/n): " yn

    case "$yn" in
    [Yy]*) return 0 ;;
    [Nn]*) return 1 ;;
    *)
      echo "Please answer y or n."
      ;;
    esac
  done
}

require_command curl
require_command sudo

if ! command -v k0s >/dev/null 2>&1; then
  echo "[ERROR] k0s is not installed."
  exit 1
fi

echo ""
echo "[ Upgrade k0s ]"
echo ""

echo "[INFO] Current version:"
k0s version

echo ""
echo "[INFO] Stopping k0s"

if ! sudo k0s stop >/dev/null 2>&1; then
  echo "[ERROR] Failed stopping k0s."

  if ! prompt_yes_no "Proceed anyway?"; then
    echo "[INFO] Exiting."
    exit 1
  fi
fi

echo ""
echo "[INFO] Downloading latest k0s"

curl -sSLf https://get.k0s.sh | sudo sh

echo "[INFO] Upgrade installed."

echo ""
echo "[INFO] Starting k0s"

sudo k0s start

echo ""
echo "[INFO] Waiting for cluster"

sleep 10

echo ""
echo "[INFO] New version:"
k0s version

echo ""
echo "[INFO] Node status:"
KUBECONFIG="${KUBECONFIG_PATH}" k0s kubectl get nodes || true

echo ""
echo "[INFO] System pods:"
KUBECONFIG="${KUBECONFIG_PATH}" k0s kubectl get pods -A || true

echo ""
echo "[INFO] k0s upgrade complete."

