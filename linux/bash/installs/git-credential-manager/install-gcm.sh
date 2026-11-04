#!/usr/bin/env bash
set -euo pipefail

REPO="git-ecosystem/git-credential-manager"
INSTALL_DIR="/usr/local/bin"

# Detect architecture
case "$(uname -m)" in
  x86_64 | amd64)
    ARCH="x64"
    ;;
  aarch64 | arm64)
    ARCH="arm64"
    ;;
  *)
    echo "Unsupported architecture: $(uname -m)"
    exit 1
    ;;
esac

# Get latest release version
VERSION="$(
  curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" |
    grep '"tag_name":' |
    head -1 |
    sed -E 's/.*"v([^"]+)".*/\1/'
)"

if [[ -z "$VERSION" ]]; then
  echo "Could not determine latest GCM version."
  exit 1
fi

FILE="gcm-linux-${ARCH}-${VERSION}.tar.gz"
URL="https://github.com/${REPO}/releases/download/v${VERSION}/${FILE}"

echo "Installing Git Credential Manager ${VERSION} (${ARCH})..."

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

curl -fL --progress-bar "$URL" -o "$TMP/$FILE"

sudo tar -xzf "$TMP/$FILE" -C "$INSTALL_DIR"

# Configure Git
git-credential-manager configure

# Azure DevOps: distinguish credentials by repository path
git config --global credential.https://dev.azure.com.useHttpPath true

echo
echo "GCM installed successfully:"
git-credential-manager --version
echo
echo "Git credential helper:"
git config --global credential.helper
