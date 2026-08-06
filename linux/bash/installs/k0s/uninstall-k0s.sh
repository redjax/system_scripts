#!/usr/bin/env bash
set -euo pipefail

NUKE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
  --nuke)
    NUKE=1
    shift
    ;;
  *)
    echo "[ERROR] Unknown argument: $1"
    exit 1
    ;;
  esac
done

if ! command -v k0s >/dev/null 2>&1; then
  echo "[INFO] k0s is not installed."
  exit 0
fi

## Stop k0s

echo ""
echo "[INFO] Stopping k0s"

sudo k0s stop || true

## Reset cluster

echo ""
echo "[INFO] Resetting k0s"

sudo k0s reset || true

## Remove systemd services

echo ""
echo "[INFO] Removing systemd services"

sudo rm -f /etc/systemd/system/k0scontroller.service
sudo rm -f /etc/systemd/system/k0sworker.service

sudo systemctl daemon-reload

## Remove binary

echo ""
echo "[INFO] Removing k0s binary"

sudo rm -f /usr/local/bin/k0s

## Remove kubeconfig

echo ""
echo "[INFO] Removing kubeconfig"

rm -rf "${HOME}/.kube"

if [[ "$NUKE" -eq 1 ]]; then
  echo ""
  echo "[WARNING] NUKE MODE ENABLED"
  echo "[INFO] Removing all Kubernetes data"

  sudo rm -rf /var/lib/k0s
  sudo rm -rf /etc/k0s

  ## Optional containerd cleanup

  sudo rm -rf /run/k0s
  sudo rm -rf /var/lib/containerd

  ## Optional CNI cleanup

  sudo rm -rf /etc/cni
  sudo rm -rf /opt/cni

  ## Network cleanup

  sudo ip link delete cni0 2>/dev/null || true
  sudo ip link delete flannel.1 2>/dev/null || true

  echo ""
  echo "[INFO] Kubernetes networking artifacts may still exist in iptables."
  echo "[INFO] A reboot is strongly recommended."
fi

echo ""
echo "[INFO] k0s uninstall complete."

