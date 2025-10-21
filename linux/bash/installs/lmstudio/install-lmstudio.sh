#!/bin/bash

set -uo pipefail

APPIMAGE_URL="https://installers.lmstudio.ai/linux/x64/0.3.26-6/LM-Studio-0.3.26-6-x64.AppImage"
APPIMAGE_NAME="LMStudio.AppImage"
APPDIR="$HOME/.local/bin"
DESKTOPFILE="$HOME/.local/share/applications/lmstudio.desktop"

# Create temp directory and cleanup trap
TMPDIR=$(mktemp -d)
cleanup() {
    rm -rf "$TMPDIR"
}
trap cleanup EXIT

# Download AppImage
echo "Downloading LM Studio AppImage..."
wget -O "$TMPDIR/$APPIMAGE_NAME" "$APPIMAGE_URL"

# Make the AppImage executable
mkdir -p "$APPDIR"
mv "$TMPDIR/$APPIMAGE_NAME" "$APPDIR/"
chmod +x "$APPDIR/$APPIMAGE_NAME"

# Create .desktop entry
mkdir -p "$(dirname "$DESKTOPFILE")"
cat > "$DESKTOPFILE" <<EOF
[Desktop Entry]
Name=LM Studio
Exec=$APPDIR/$APPIMAGE_NAME
Icon=application-default-icon
Type=Application
Categories=Utility;
Comment=Run LM Studio AppImage
EOF

echo "LM Studio AppImage installed to $APPDIR"
echo ".desktop launcher created at $DESKTOPFILE"
