#!/bin/bash
set -e

## i.e. git{hub,lab}.com/username/repositoryname
REPO="cooperspencer/gickup"

## Check for required commands
for cmd in curl sha256sum tar; do
  if ! command -v $cmd &>/dev/null; then
    echo "$cmd is required but not installed."
    exit 1
  fi
done

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

## Check if gickup is already installed
GICKUP_INSTALLED=$(command -v gickup)

if [ -n "GICKUP_INSTALLED" ]; then
  echo "gickup is already installed. Update will be applied if a new version is available."
fi

echo "Checking latest gickup version"

## Get latest gickup release version (strip leading 'v')
RAW_VERSION=$(curl -s https://api.github.com/repos/$REPO/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
GICKUP_VERSION="${RAW_VERSION#v}"

if [ -z "$GICKUP_VERSION" ]; then
  echo "Could not determine the latest gickup version."
  exit 1
fi

echo "Latest: $GICKUP_VERSION"

## Compose asset and checksum filenames/URLs
ASSET_FILE="gickup_${GICKUP_VERSION}_${ASSET_OS}_${ASSET_ARCH}.tar.gz"
CHECKSUM_FILE="gickup_${GICKUP_VERSION}_checksums.txt"
DOWNLOAD_URL="https://github.com/${REPO}/releases/download/v${GICKUP_VERSION}/${ASSET_FILE}"
CHECKSUM_URL="https://github.com/${REPO}/releases/download/v${GICKUP_VERSION}/${CHECKSUM_FILE}"

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

echo "Downloading checksum file"
## Download checksum if not present
if [ ! -f "$TMPDIR/$CHECKSUM_FILE" ]; then
  echo "Downloading $CHECKSUM_FILE..."
  curl -L -o "$TMPDIR/$CHECKSUM_FILE" "$CHECKSUM_URL"
else
  echo "$CHECKSUM_FILE already exists in $TMPDIR, skipping download."
fi

cd "$TMPDIR"

echo "Verifying checksum..."
sha256sum -c "$CHECKSUM_FILE" --ignore-missing

echo "Extracting gickup binary"
tar -xzf "$ASSET_FILE"

BIN_NAME="gickup"
if [ -f "$BIN_NAME" ]; then
  echo "Updating gickup"

  sudo mv "$BIN_NAME" /usr/local/bin/
  sudo chmod +x /usr/local/bin/$BIN_NAME
else
  ## If tarball contains a directory, find the binary
  BIN_PATH=$(tar -tzf "$ASSET_FILE" | grep -m1 "$BIN_NAME")
  if [ -z "$BIN_PATH" ]; then
    echo "Could not find gickup binary in the archive."
    exit 1
  fi

  echo "Installing gickup to /usr/local/bin/$BIN_NAME"
  sudo mv "$BIN_PATH" /usr/local/bin/$BIN_NAME
  sudo chmod +x /usr/local/bin/$BIN_NAME
fi

echo "gickup v$GICKUP_VERSION installed successfully."
