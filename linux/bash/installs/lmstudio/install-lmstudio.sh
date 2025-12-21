#!/bin/bash

set -uo pipefail

## Detect CPU architecture
CPU_ARCH=$(uname -m)
case "$CPU_ARCH" in
x86_64) CPU_ARCH="x64" ;;
aarch64 | arm64) CPU_ARCH="arm64" ;;
*)
  echo "ERROR: Unsupported architecture: $CPU_ARCH" >&2
  exit 1
  ;;
esac

APPIMAGE_NAME="LM-Studio.AppImage"
APPDIR="$HOME/.local/bin"
DESKTOPFILE="$HOME/.local/share/applications/lmstudio.desktop"

## Stop any running LM Studio first
if pgrep -f "$APPIMAGE_NAME" >/dev/null 2>&1; then
  echo "Stopping running LM Studio"
  pkill -f "$APPIMAGE_NAME"
  sleep 2 # Give it time to shut down cleanly
fi

## Create temp directory and cleanup trap
TMPDIR=$(mktemp -d)
cleanup() {
  rm -rf "$TMPDIR"
}
trap cleanup EXIT

##  Download latest AppImage using official latest URL
echo "Downloading latest LM Studio AppImage for $CPU_ARCH"
curl -L "https://lmstudio.ai/download/latest/linux/$CPU_ARCH" \
  --output "$TMPDIR/$APPIMAGE_NAME"

##  Make the AppImage executable
mkdir -p "$APPDIR"
mv "$TMPDIR/$APPIMAGE_NAME" "$APPDIR/"
chmod +x "$APPDIR/$APPIMAGE_NAME"

##  Create .desktop entry
mkdir -p "$(dirname "$DESKTOPFILE")"
cat >"$DESKTOPFILE" <<EOF
[Desktop Entry]
Name=LM Studio
Exec=$APPDIR/$APPIMAGE_NAME
Icon=application-default-icon
Type=Application
Categories=Utility;
Comment=Run LM Studio AppImage
EOF

echo "LM Studio updated and installed to $APPDIR"
echo ".desktop launcher created at $DESKTOPFILE"
echo ""
echo "You can now launch LM Studio from your applications menu."
