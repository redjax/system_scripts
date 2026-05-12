#!/usr/bin/env bash
set -euo pipefail

echo "[INFO] Installing kubectl"

ARCH="$(uname -m)"
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"

if [[ "$OS" != "linux" ]]; then
  echo "[ERROR] This script only supports Linux."
  exit 1
fi

## Normalize architecture
case "$ARCH" in
x86_64) ARCH="amd64" ;;
aarch64 | arm64) ARCH="arm64" ;;
armv7l) ARCH="arm" ;;
*)
  echo "[ERROR] Unsupported architecture: $ARCH"
  exit 1
  ;;
esac

install_binary() {
  echo "[INFO] Installing kubectl via official binary"

  VERSION="$(curl -L -s https://dl.k8s.io/release/stable.txt)"
  URL="https://dl.k8s.io/release/${VERSION}/bin/linux/${ARCH}/kubectl"

  curl -LO "$URL"
  chmod +x kubectl
  sudo mv kubectl /usr/local/bin/kubectl

  echo "[INFO] kubectl installed: $(kubectl version --client --short || true)"
}

## Debian / Ubuntu
if command -v apt-get >/dev/null 2>&1; then
  echo "[INFO] Detected Debian/Ubuntu"
  sudo apt-get update -y
  sudo apt-get install -y kubectl || install_binary
  exit 0
fi

## RHEL / CentOS / Rocky / Alma
if command -v dnf >/dev/null 2>&1; then
  echo "[INFO] Detected RHEL-based (dnf)"
  sudo dnf install -y kubectl || install_binary
  exit 0
fi

if command -v yum >/dev/null 2>&1; then
  echo "[INFO] Detected RHEL-based (yum)"
  sudo yum install -y kubectl || install_binary
  exit 0
fi

## openSUSE
if command -v zypper >/dev/null 2>&1; then
  echo "[INFO] Detected openSUSE"
  sudo zypper install -y kubectl || install_binary
  exit 0
fi

## Arch Linux
if command -v pacman >/dev/null 2>&1; then
  echo "[INFO] Detected Arch Linux"
  sudo pacman -Sy --noconfirm kubectl || install_binary
  exit 0
fi

## Alpine Linux
if command -v apk >/dev/null 2>&1; then
  echo "[INFO] Detected Alpine Linux"
  sudo apk add kubectl || install_binary
  exit 0
fi

## Binary install fallback
echo "[WARN] Unknown distro. Falling back to binary install."
install_binary

