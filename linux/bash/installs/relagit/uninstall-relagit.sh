#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="$HOME/.local/share/relagit"
BIN_PATH="$HOME/.local/bin/relagit"

DESKTOP_FILE="$HOME/.local/share/applications/relagit.desktop"

ICON_PATH="$HOME/.local/share/icons/hicolor/512x512/apps/relagit.png"

function remove_if_exists() {
  local path="$1"

  if [[ -e "$path" ]]; then
    echo "Removing:"
    echo "  $path"

    rm -rf "$path"
  fi
}

function refresh_desktop() {
  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database \
      "$HOME/.local/share/applications" >/dev/null 2>&1 || true
  fi

  if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache \
      "$HOME/.local/share/icons/hicolor" >/dev/null 2>&1 || true
  fi
}

echo "Uninstalling RelaGit"

## Remove installed files
remove_if_exists "$INSTALL_DIR"

## Remove CLI launcher
remove_if_exists "$BIN_PATH"

## Remove desktop entry
remove_if_exists "$DESKTOP_FILE"

## Remove icon
remove_if_exists "$ICON_PATH"

## Refresh desktop integration
refresh_desktop

echo
echo "RelaGit has been removed."

