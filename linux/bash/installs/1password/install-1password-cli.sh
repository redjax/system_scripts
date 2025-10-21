#!/bin/bash
set -e

if ! command -v curl &>/dev/null; then
  echo "curl is not installed."
  exit 1
fi

if ! command -v unzip &>/dev/null; then
  echo "unzip is not installed."
  exit 1
fi

## Detect architecture and map to 1Password naming convention
ARCH=$(uname -m)
case "$ARCH" in
  x86_64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *)
    echo "Unsupported architecture: $ARCH"
    exit 1
    ;;
esac

## Latest stable version – update as needed from https://developer.1password.com/docs/cli/get-started/
VERSION="2.26.1"

TMPDIR=$(mktemp -d)
ZIP_URL="https://cache.agilebits.com/dist/1P/op2/pkg/v${VERSION}/op_linux_${ARCH}_v${VERSION}.zip"
ZIP_FILE="$TMPDIR/op.zip"

echo "Downloading 1Password CLI v$VERSION for architecture $ARCH..."
curl -fSL "$ZIP_URL" -o "$ZIP_FILE"

echo "Extracting $ZIP_FILE..."
unzip -q "$ZIP_FILE" -d "$TMPDIR"

echo "Installing binary to /usr/local/bin/op (requires sudo)..."
sudo install -m 755 "$TMPDIR/op" /usr/local/bin/op

## Optionally create onepassword-cli group (from docs)
if ! getent group onepassword-cli >/dev/null; then
  echo "Creating onepassword-cli group..."
  sudo groupadd --system onepassword-cli
fi

## Set ownership/group and permissions on binary as recommended
sudo chown root:onepassword-cli /usr/local/bin/op
sudo chmod 750 /usr/local/bin/op

rm -rf "$TMPDIR"

echo "1Password CLI installed successfully."
echo "Adding user to 1Password group"

sudo usermod -aG onepassword-cli $USER

if [[ $? -ne 0 ]]; then
  echo "[ERROR] Failed to install 1Password CLI to /usr/local/bin/op"
  exit 1
else
  echo "[INFO] Successfully installed 1Password CLI to /usr/local/bin/op"
  echo "You should make sure your ~/.bashrc adds /usr/local/bin to your \$PATH"
  echo ""
  echo "Restart your shell by closing/re-opening the terminal, or running one of the following:"
  echo "  $> . ~/.bashrc"
  echo "  $> exec \$SHELL"
  echo "  $> baash --login"
  echo ""

  exit 0
fi