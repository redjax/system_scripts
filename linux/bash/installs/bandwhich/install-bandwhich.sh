#!/usr/bin/env bash
set -euo pipefail

REPO="imsnif/bandwhich"

# Create temp directory for staging
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

echo "[+] Fetching latest release info from GitHub for $REPO"

# Get JSON of latest release
RELEASE_JSON="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest")"

# Extract version tag (e.g., v0.23.1)
TAG="$(printf "%s" "$RELEASE_JSON" | grep -m1 '"tag_name"' | sed -E 's/.*"tag_name": "([^"]+)".*/\1/')"
VERSION="${TAG#v}"

OS="$(uname -s)"
ARCH="$(uname -m)"

# Map architecture names
case "$ARCH" in
    x86_64|amd64) ARCH="x86_64" ;;
    aarch64|arm64) ARCH="aarch64" ;;
    *) echo "[-] Unsupported architecture: $ARCH"; exit 1 ;;
esac

# Determine asset name pattern
if [ "$OS" = "Darwin" ]; then
    PATTERN="bandwhich-v$VERSION-$ARCH-apple-darwin"
else
    # Linux: try musl first
    PATTERN="bandwhich-v$VERSION-$ARCH-unknown-linux-musl"
fi

# Extract matching asset name from JSON
ASSET=$(printf "%s" "$RELEASE_JSON" | grep -oE "\"name\": \"$PATTERN[^\"]+\"" | sed -E 's/"name": "//; s/"$//')

# Linux fallback to gnu if musl not found
if [ -z "$ASSET" ] && [ "$OS" != "Darwin" ]; then
    echo "[!] musl asset not found, trying gnu"
    PATTERN="bandwhich-v$VERSION-$ARCH-unknown-linux-gnu"
    ASSET=$(printf "%s" "$RELEASE_JSON" | grep -oE "\"name\": \"$PATTERN[^\"]+\"" | sed -E 's/"name": "//; s/"$//')
fi

if [ -z "$ASSET" ]; then
    echo "[-] Could not find a suitable asset for your OS/arch"
    exit 1
fi

# Extract download URL
URL=$(printf "%s" "$RELEASE_JSON" | grep -oE "\"browser_download_url\": \"[^\"]+$ASSET\"" | sed -E 's/"browser_download_url": "//; s/"$//')

echo "[+] Downloading $ASSET"
curl -fsSL -o "$TMPDIR/$ASSET" "$URL"

cd "$TMPDIR"

# Extract archive
if [[ "$ASSET" == *.tar.gz ]]; then
    tar xf "$ASSET"
elif [[ "$ASSET" == *.zip ]]; then
    unzip -q "$ASSET"
else
    echo "[-] Unknown archive format: $ASSET"
    exit 1
fi

# Find binary
BINARY="$(find . -type f -name 'bandwhich' | head -n 1)"
if [ ! -f "$BINARY" ]; then
    echo "[-] Failed to locate extracted bandwhich binary."
    exit 1
fi

echo "[+] Installing bandwhich to /usr/local/bin"
sudo install -m 755 "$BINARY" /usr/local/bin/bandwhich

echo "[✓] bandwhich $VERSION installed successfully!"
echo "Run: bandwhich"
