#!/usr/bin/env bash
set -euo pipefail

# Detect OS
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"

case "$ARCH" in
x86_64 | amd64) ARCH="amd64" ;;
arm64 | aarch64) ARCH="arm64" ;;
*)
  echo "Unsupported architecture: $ARCH"
  exit 1
  ;;
esac

# Get latest version from GitHub API
LATEST=$(curl -s https://api.github.com/repos/block/scaffolder/releases/latest |
  grep '"tag_name":' |
  sed -E 's/.*"([^"]+)".*/\1/')

# Remove leading 'v' if present
VERSION="${LATEST#v}"

# Build asset name
FILE="scaffolder-${VERSION}-${OS}-${ARCH}.tar.gz"

# Download to temp directory
TMPDIR=$(mktemp -d)
echo "Downloading $FILE to $TMPDIR..."
curl -L -o "$TMPDIR/$FILE" "https://github.com/block/scaffolder/releases/download/${LATEST}/$FILE"

# Extract
tar -xzf "$TMPDIR/$FILE" -C "$TMPDIR"

# Install (move binary to /usr/local/bin)
sudo mv "$TMPDIR/scaffolder" /usr/local/bin/
chmod +x /usr/local/bin/scaffolder

# Cleanup
rm -rf "$TMPDIR"

echo "Scaffolder $LATEST installed successfully!"
