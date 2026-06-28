#!/usr/bin/env bash

set -euo pipefail

REPO="relagit/relagit"
ASSET_NAME="RelaGit-linux.tar.gz"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

INSTALL_DIR="$HOME/.local/share/relagit"
BIN_DIR="$HOME/.local/bin"

mkdir -p "$INSTALL_DIR"
mkdir -p "$BIN_DIR"

function require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing dependency: $1"
    exit 1
  }
}

function find_icon() {
  local icon

  icon="$(
    find "$INSTALL_DIR" -type f \
      \( -iname '*512*.png' \
      -o -iname '*256*.png' \
      -o -iname '*icon*.png' \
      -o -iname '*.png' \) |
      sort |
      head -n1
  )"

  if [[ -z "$icon" ]]; then
    icon="$(
      find "$INSTALL_DIR" -type f -iname '*.svg' |
        sort |
        head -n1
    )"
  fi

  echo "$icon"
}

function refresh_desktop() {
  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true
  fi

  if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache \
      "$HOME/.local/share/icons/hicolor" >/dev/null 2>&1 || true
  fi

  if command -v gio >/dev/null 2>&1; then
    gio set "$DESKTOP_FILE" metadata::trusted true >/dev/null 2>&1 || true
  fi
}

echo "Using temp dir:"
echo "  $TMP_DIR"

## Dependencies
for cmd in curl tar grep sed find chmod file install; do
  require_cmd "$cmd"
done

API_URL="https://api.github.com/repos/${REPO}/releases/latest"

echo "Fetching latest release metadata"

RELEASE_JSON="$(curl -fsSL "$API_URL")"

DOWNLOAD_URL="$(
  echo "$RELEASE_JSON" |
    grep -Eo 'https://[^"]+' |
    grep "/${ASSET_NAME}$" |
    head -n1
)"

if [[ -z "$DOWNLOAD_URL" ]]; then
  echo "Could not find asset:"
  echo "  $ASSET_NAME"
  exit 1
fi

ARCHIVE_PATH="${TMP_DIR}/${ASSET_NAME}"

echo
echo "Downloading:"
echo "  $DOWNLOAD_URL"

curl -fL "$DOWNLOAD_URL" -o "$ARCHIVE_PATH"

echo
echo "Extracting"

EXTRACT_DIR="${TMP_DIR}/extract"
mkdir -p "$EXTRACT_DIR"

tar -xzf "$ARCHIVE_PATH" -C "$EXTRACT_DIR"

## Replace old install
rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"

cp -r "$EXTRACT_DIR"/* "$INSTALL_DIR"/

## Locate actual executable
EXECUTABLE="$(
  find "$INSTALL_DIR" -type f -perm -111 |
    grep -viE '\.(so|dll|node)$' |
    head -n1
)"

if [[ -z "$EXECUTABLE" ]]; then
  echo "Could not locate RelaGit executable."
  echo
  echo "Installed files:"
  find "$INSTALL_DIR"
  exit 1
fi

chmod +x "$EXECUTABLE"

echo
echo "Executable:"
echo "  $EXECUTABLE"

## Create CLI launcher
LAUNCHER="${BIN_DIR}/relagit"

cat >"$LAUNCHER" <<EOF
#!/usr/bin/env bash
exec "$EXECUTABLE" "\$@"
EOF

chmod +x "$LAUNCHER"

echo
echo "Launcher created:"
echo "  $LAUNCHER"

## Locate icon
ICON_PATH="$(find_icon)"

echo
echo "Icon:"
echo "  ${ICON_PATH:-none}"

## Install icon into hicolor theme
ICON_THEME_DIR="$HOME/.local/share/icons/hicolor/512x512/apps"
mkdir -p "$ICON_THEME_DIR"

INSTALLED_ICON="$ICON_THEME_DIR/relagit.png"

if [[ -n "$ICON_PATH" ]]; then
  install -Dm644 "$ICON_PATH" "$INSTALLED_ICON"
fi

## Create desktop entry
DESKTOP_DIR="$HOME/.local/share/applications"
mkdir -p "$DESKTOP_DIR"

DESKTOP_FILE="${DESKTOP_DIR}/relagit.desktop"

cat >"$DESKTOP_FILE" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=RelaGit
Comment=Git Client
Exec=$EXECUTABLE
Icon=relagit
Terminal=false
Categories=Development;Git;
StartupNotify=true
StartupWMClass=RelaGit
EOF

chmod 644 "$DESKTOP_FILE"

echo
echo "Desktop entry:"
echo "  $DESKTOP_FILE"

## Refresh desktop integration
refresh_desktop

## PATH check
if [[ ":$PATH:" != *":${BIN_DIR}:"* ]]; then
  echo
  echo "Add this to your shell config:"
  echo
  echo 'export PATH="$HOME/.local/bin:$PATH"'
fi

echo
echo "Installed RelaGit to:"
echo "  $INSTALL_DIR"

echo
echo "Done."
echo
echo "Run from terminal:"
echo "  relagit"

echo
echo "Or launch from your desktop environment search."

