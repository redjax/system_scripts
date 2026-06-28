#!/usr/bin/env bash
set -euo pipefail

command -v curl >/dev/null || {
  echo "curl is not installed."
  exit 1
}
command -v unzip >/dev/null || {
  echo "unzip is not installed."
  exit 1
}

OS="$(uname -s)"
ARCH="$(uname -m)"

SG_VERSION="$(curl -fsSL https://api.github.com/repos/sourcegit-scm/sourcegit/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')"
SG_VERSION="${SG_VERSION#v}"

echo "Installing sourcegit v${SG_VERSION}"

case "$OS" in
Linux)
  case "$ARCH" in
  x86_64)
    FILE="sourcegit-${SG_VERSION}-1.x86_64.rpm"
    ;;
  aarch64 | arm64)
    FILE="sourcegit-${SG_VERSION}-1.aarch64.rpm"
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

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

URL="https://github.com/sourcegit-scm/sourcegit/releases/download/v${SG_VERSION}/${FILE}"
ARCHIVE="$TMPDIR/$FILE"

echo "Downloading $FILE from $URL"
curl -fL -o "$ARCHIVE" "$URL"

if [[ "$OS" == "Darwin" ]]; then
  unzip -o "$ARCHIVE" -d "$TMPDIR"
  BIN_PATH="$(find "$TMPDIR" -type f -name sourcegit | head -n 1)"
  [[ -n "$BIN_PATH" ]] || {
    echo "sourcegit binary not found in archive."
    exit 1
  }
  install -m 755 "$BIN_PATH" /usr/local/bin/sourcegit
elif [[ "$OS" == "Linux" ]]; then
  if command -v dnf >/dev/null; then
    sudo dnf install -y "$ARCHIVE"
  else
    sudo rpm -Uvh --replacepkgs "$ARCHIVE"
  fi
fi

echo "sourcegit installed successfully"

