#!/usr/bin/env bash

set -e

if ! command -v curl &>/dev/null; then
  echo "curl is not installed."
  exit 1
fi

OS="$(uname -s)"
ARCH="$(uname -m)"

## Detect distro using /etc/os-release
if [ -f /etc/os-release ]; then
  . /etc/os-release
  DISTRO_ID=$ID
else
  echo "Cannot detect Linux distribution."
  exit 1
fi

## Get latest version from GitHub API
SG_VERSION=$(curl -s https://api.github.com/repos/sourcegit-scm/sourcegit/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
SG_VERSION="${SG_VERSION#v}"

echo "Installing sourcegit v${SG_VERSION}"

## Map to GitHub asset names
case "$OS" in
Linux)
  case "$ARCH" in
    x86_64)
      FILE="sourcegit-${SG_VERSION}-1.x86_64.rpm"
      APPIMAGE="sourcegit-${SG_VERSION}.linux.x86_64.AppImage"
      ;;
    aarch64|arm64)
      FILE="sourcegit-${SG_VERSION}-1.aarch64.rpm"
      APPIMAGE="sourcegit-${SG_VERSION}.linux.arm64.AppImage"
      ;;
    *)
      echo "Unsupported Linux architecture: $ARCH"
      exit 1
      ;;
  esac
  ;;
Darwin)
  case "$ARCH" in
    x86_64)
      FILE="sourcegit_${SG_VERSION}.osx-x64.zip"
      ;;
    arm64)
      FILE="sourcegit_${SG_VERSION}.osx-arm64.zip"
      ;;
    *)
      echo "Unsupported macOS architecture: $ARCH"
      exit 1
      ;;
  esac
  ;;
*)
  echo "Unsupported OS: $OS"
  exit 1
  ;;
esac

TMPDIR=$(mktemp -d)

## Download the release
URL="https://github.com/sourcegit-scm/sourcegit/releases/download/v${SG_VERSION}/$FILE"
ARCHIVE="$TMPDIR/$FILE"

echo "Downloading $FILE from $URL"
curl -L -o "$ARCHIVE" "$URL"

## Install/extract
if [ "$OS" = "Darwin" ]; then
  echo "Extracting $ARCHIVE"
  unzip -o "$ARCHIVE" -d "$TMPDIR"

  ## Find the binary (assume it's named 'sourcegit')
  BIN_PATH=$(find "$TMPDIR" -type f -name 'sourcegit' | head -n 1)
  
  if [ -z "$BIN_PATH" ]; then
    echo "sourcegit binary not found in archive."
    exit 1
  fi
  
  install -m 755 "$BIN_PATH" /usr/local/bin/
elif [ "$OS" = "Linux" ]; then
  if [[ "$FILE" == *.rpm ]]; then
    echo "Installing RPM package (requires sudo)"
    
    sudo rpm -i --replacepkgs "$ARCHIVE"
  elif [[ "$FILE" == *.AppImage ]]; then
    chmod +x "$ARCHIVE"
    
    sudo mv "$ARCHIVE" /usr/local/bin/sourcegit
  else
    echo "Unknown Linux asset type: $FILE"
    
    exit 1
  fi
fi

if [[ $? -ne 0 ]]; then
  echo "[ERROR] Failed to install sourcegit."
  exit 1
else
    echo "sourcegit installed successfully!"
    exit 0
fi
