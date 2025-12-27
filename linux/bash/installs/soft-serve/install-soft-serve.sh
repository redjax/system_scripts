#!/usr/bin/env bash
set -uo pipefail

# -------------------------------
# Requirements
# -------------------------------
if ! command -v curl &>/dev/null; then
    echo "[ERROR] curl is not installed."
    exit 1
fi

if ! command -v jq &>/dev/null; then
    echo "[ERROR] jq is not installed."
    exit 1
fi

# -------------------------------
# Variables
# -------------------------------
REPO="charmbracelet/soft-serve"
INSTALL_DIR="/usr/local/bin"

# Detect OS and architecture
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$ARCH" in
    x86_64)
        ARCH="x86_64"
        DEB_ARCH="amd64"
        ;;
    aarch64)
        ARCH="arm64"
        DEB_ARCH="arm64"
        ;;
    armv7l)
        ARCH="armv7"
        DEB_ARCH="armhf"
        ;;
    i386|i686)
        ARCH="i386"
        DEB_ARCH="i386"
        ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

echo "Detected OS: $OS, Arch: $ARCH"

# -------------------------------
# Get latest release asset
# -------------------------------
ASSET_URL=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" \
    | jq -r --arg os "$OS" --arg arch "$ARCH" --arg deb_arch "$DEB_ARCH" '
        .assets[] |
        select(
            (.name | ascii_downcase | contains($os)) and
            (
                (.name | test($arch; "i")) or
                (.name | test($deb_arch; "i"))
            )
        ) | .browser_download_url' \
    | head -n1)

if [ -z "$ASSET_URL" ]; then
    echo "No matching release for OS=$OS and ARCH=$ARCH found."
    exit 1
fi

echo "Downloading from: $ASSET_URL"

# -------------------------------
# Download
# -------------------------------
TMPFILE=$(mktemp)
TMPDIR=$(mktemp -d)

function cleanup() {
    rm -f "$TMPFILE"
    rm -rf "$TMPDIR"
}
trap cleanup EXIT

curl -L "$ASSET_URL" -o "$TMPFILE"

# -------------------------------
# Install
# -------------------------------
if [[ "$ASSET_URL" == *.deb ]]; then
    echo "Installing .deb package"
    sudo dpkg -i "$TMPFILE" || sudo apt-get install -f -y
elif [[ "$ASSET_URL" == *.rpm ]]; then
    echo "Installing .rpm package"
    sudo rpm -i "$TMPFILE" || sudo dnf install -y "$TMPFILE" || sudo yum install -y "$TMPFILE"
elif [[ "$ASSET_URL" == *.tar.gz ]]; then
    echo "Extracting tarball"
    tar -xzf "$TMPFILE" -C "$TMPDIR"

    # Search inside the temp directory for the binary
    BIN_PATH=$(find "$TMPDIR" -type f -name "soft" -perm /111 | head -n1)

    if [ -f "$BIN_PATH" ]; then
        sudo mv "$BIN_PATH" "$INSTALL_DIR/soft"
        sudo chmod +x "$INSTALL_DIR/soft"
        echo "Installed to $INSTALL_DIR/soft"
    else
        echo "soft binary not found in tarball"
        exit 1
    fi
else
    echo "Unknown package format; please install manually."
    exit 1
fi

echo "Soft Serve installation complete!"
