#!/usr/bin/env bash

set -uo pipefail

ORIGINAL_PATH="$(pwd)"

## Detect platform and architecture in Go-style naming
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$ARCH" in
x86_64) ARCH="x86_64" ;;
aarch64 | arm64) ARCH="arm64" ;;
armv6l | armv7l) ARCH="armv6" ;;
i386 | i686) ARCH="i386" ;;
*)
  echo "Unsupported architecture: $ARCH" >&2
  exit 1
  ;;
esac

EXT="tar.gz"
[ "$OS" = "windows" ] && EXT="zip"

## Create a temporary directory and setup cleanup trap
TMPDIR=$(mktemp -d)
cleanup() {
  echo "Cleaning up"
  cd "$ORIGINAL_PATH"
  rm -rf "$TMPDIR"
}
trap cleanup EXIT

## Change to temp directory
cd "$TMPDIR"

## Get latest version tag
LATEST_TAG=$(curl -fsSL https://api.github.com/repos/Adembc/lazyssh/releases/latest | jq -r .tag_name)

ASSET="lazyssh_$(echo "$OS" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')_${ARCH}.${EXT}"
URL="https://github.com/Adembc/lazyssh/releases/download/${LATEST_TAG}/${ASSET}"

echo "Downloading lazyssh ${LATEST_TAG} for ${OS}_${ARCH}"
curl -fsSL -O -L "$URL"

## Extract based on file type
if [[ "$EXT" == "zip" ]]; then
  unzip "$ASSET"
else
  tar -xzf "$ASSET"
fi

## Move binary to PATH
sudo mv lazyssh /usr/local/bin/lazyssh
sudo chmod +x /usr/local/bin/lazyssh

echo "Finished installing lazyssh"
