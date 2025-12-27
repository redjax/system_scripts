#!/usr/bin/env bash
set -euo pipefail

OS="$(uname -s)"

echo "Installing XMCL for $OS"

if [[ "$OS" == "Darwin" ]]; then
    TMPDIR="$(mktemp -d)"
    trap 'rm -rf "$TMPDIR"' EXIT

    echo "macOS detected, installing DMG"

    ## Get latest release tag
    TAG="$(curl -fsSL https://api.github.com/repos/Tiiffi/x-minecraft-launcher/releases/latest \
        | grep -Eo '"tag_name": ?"[^"]+"' | cut -d'"' -f4)"

    [[ -n "$TAG" ]] || { echo "Failed to get latest XMCL release tag"; exit 1; }

    ## Find DMG URL
    URL="$(curl -fsSL "https://api.github.com/repos/Tiiffi/x-minecraft-launcher/releases/tags/$TAG" \
        | grep -Eo '"browser_download_url": ?"[^"]+\.dmg"' \
        | cut -d'"' -f4 \
        | head -n1)"

    [[ -n "$URL" ]] || { echo "Failed to find DMG"; exit 1; }

    FILE="$TMPDIR/XMCL.dmg"
    echo "Downloading $URL"
    curl -L "$URL" -o "$FILE"

    echo "Mounting DMG"
    MOUNTDIR="$(hdiutil attach "$FILE" | grep -o '/Volumes/.*')"
    APP_PATH="$MOUNTDIR/X Minecraft Launcher.app"

    sudo cp -R "$APP_PATH" /Applications/
    
    sudo xattr -cr "/Applications/X Minecraft Launcher.app"
    hdiutil detach "$MOUNTDIR"

    echo "XMCL installed to /Applications/X Minecraft Launcher.app"
    
    exit 0
fi

if [[ "$OS" == "Linux" ]]; then
    if command -v flatpak >/dev/null 2>&1; then
        echo "Flatpak detected, installing XMCL from Flathub"
        
        flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
        flatpak install -y flathub app.xmcl.voxelum
        
        echo "XMCL installed via Flatpak"
        
        exit 0
    fi

    echo "Flatpak not found, falling back to AppImage"

    TMPDIR="$(mktemp -d)"
    trap 'rm -rf "$TMPDIR"' EXIT

    ## Get latest release tag
    TAG="$(curl -fsSL https://api.github.com/repos/Tiiffi/x-minecraft-launcher/releases/latest \
        | grep -Eo '"tag_name": ?"[^"]+"' | cut -d'"' -f4)"

    [[ -n "$TAG" ]] || { echo "Failed to get latest XMCL release tag"; exit 1; }

    ## Find AppImage URL
    URL="$(curl -fsSL "https://api.github.com/repos/Tiiffi/x-minecraft-launcher/releases/tags/$TAG" \
        | grep -Eo '"browser_download_url": ?"[^"]+AppImage"' \
        | cut -d'"' -f4 \
        | head -n1)"

    [[ -n "$URL" ]] || { echo "Failed to find AppImage"; exit 1; }

    FILE="$TMPDIR/$(basename "$URL")"
    
    echo "Downloading $URL"
    curl -L "$URL" -o "$FILE"

    chmod +x "$FILE"
    
    sudo mv "$FILE" /usr/local/bin/xmcl
    
    echo "XMCL AppImage installed to /usr/local/bin/xmcl"
    
    exit 0
fi

echo "Unsupported OS: $OS"
exit 1
