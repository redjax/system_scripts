#!/usr/bin/env bash

set -euo pipefail

########################################
# k0s single-node installer
########################################

KUBECONFIG_SOURCE="/var/lib/k0s/pki/admin.conf"
KUBECONFIG_DEST="${HOME}/.kube/config"

function require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "[ERROR] Required command not found: $1"
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

if command -v k0s >/dev/null 2>&1; then
  echo "[INFO] k0s is already installed."

  if ! prompt_yes_no "Proceed anyway?"; then
    echo "[INFO] Exiting."
    exit 0
  fi
fi

echo "[INFO] Downloading and installing k0s"

curl -sSLf https://get.k0s.sh | sudo sh

echo "[INFO] k0s installed successfully."

if prompt_yes_no "Install single-node controller?"; then
  echo "[INFO] Installing k0s controller"

  sudo k0s install controller --single

  echo "[INFO] Controller installed."
fi

if prompt_yes_no "Start k0s now?"; then
  echo "[INFO] Starting k0s"

  sudo k0s start

  echo "[INFO] Waiting for Kubernetes API"

  sleep 10

  echo "[INFO] Configuring kubectl access"

  mkdir -p "${HOME}/.kube"

  sudo cp "${KUBECONFIG_SOURCE}" "${KUBECONFIG_DEST}"

  sudo chown "$(id -u):$(id -g)" "${KUBECONFIG_DEST}"

  chmod 600 "${KUBECONFIG_DEST}"

  echo "[INFO] kubeconfig installed:"
  echo "       ${KUBECONFIG_DEST}"

  echo ""
  echo "[INFO] Cluster status:"
  k0s kubectl get nodes || true

  echo ""
  echo "[INFO] System pods:"
  k0s kubectl get pods -A || true
fi

echo ""
echo "[INFO] k0s setup complete."

