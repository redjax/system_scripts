#!/usr/bin/env bash
set -eo pipefail

if ! command -v curl &>/dev/null; then
    echo "[ERROR] curl is not installed."
    exit 1
fi

REPO="git-bug/git-bug"

## Detect OS and ARCH for asset naming
case "$(uname -s)" in
  Linux)
    ASSET_OS="linux"
    case "$(uname -m)" in
      x86_64)   ASSET_ARCH="amd64" ;;
      aarch64|arm64) ASSET_ARCH="arm64" ;;
      armv6l)   ASSET_ARCH="armv6" ;;
      armv7l)   ASSET_ARCH="armv7" ;;
      i386|i686) ASSET_ARCH="386" ;;
      *) echo "Unsupported Linux architecture: $(uname -m)"; exit 1 ;;
    esac
    ;;
  Darwin)
    ASSET_OS="darwin"
    case "$(uname -m)" in
      x86_64) ASSET_ARCH="amd64" ;;
      arm64)  ASSET_ARCH="arm64" ;;
      *) echo "Unsupported macOS architecture: $(uname -m)"; exit 1 ;;
    esac
    ;;
  *)
    echo "Unsupported OS: $(uname -s)"
    exit 1
    ;;
esac

echo "Checking latest git-bug version"

RAW_VERSION=$(curl -s https://api.github.com/repos/$REPO/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
GITBUG_VERSION="${RAW_VERSION#v}"

echo "Latest: ${GITBUG_VERSION}"

## Compose asset and checksum filenames/URLs
ASSET_FILE="git-bug_${ASSET_OS}_${ASSET_ARCH}"
DOWNLOAD_URL="https://github.com/${REPO}/releases/download/v${GITBUG_VERSION}/${ASSET_FILE}"

## Create temp directory
TMPDIR="${TMPDIR:-$(mktemp -d)}"
echo "Using temp directory: $TMPDIR"

## Download asset if not present
if [ ! -f "$TMPDIR/$ASSET_FILE" ]; then
  echo "Downloading $ASSET_FILE..."
  curl -L -o "$TMPDIR/$ASSET_FILE" "$DOWNLOAD_URL"
else
  echo "$ASSET_FILE already exists in $TMPDIR, skipping download."
fi

BIN_NAME="git-bug"
INSTALL_PATH="/usr/local/bin/$BIN_NAME"

echo "Installing git-bug to $INSTALL_PATH"
sudo cp "$TMPDIR/$ASSET_FILE" "$INSTALL_PATH"
sudo chmod +x "$INSTALL_PATH"

echo "git-bug v$GITBUG_VERSION installed successfully."
