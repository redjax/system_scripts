#!/usr/bin/env bash
set -euo pipefail

INSTALLER_URL="https://sw.kovidgoyal.net/kitty/installer.sh"
KITTY_APP_DIR="${HOME}/.local/kitty.app"
PATH_LINK_DIR="${HOME}/.local/bin"
APPS_DIR="${HOME}/.local/share/applications"
CONFIG_DIR="${HOME}/.config"

mkdir -p "${PATH_LINK_DIR}" "${APPS_DIR}" "${CONFIG_DIR}"

echo "Installing kitty"
curl -L "${INSTALLER_URL}" | sh /dev/stdin

echo "Creating symlinks in ${PATH_LINK_DIR}"
ln -sf "${KITTY_APP_DIR}/bin/kitty" "${PATH_LINK_DIR}/kitty"
ln -sf "${KITTY_APP_DIR}/bin/kitten" "${PATH_LINK_DIR}/kitten"

echo "Installing desktop files"
cp "${KITTY_APP_DIR}/share/applications/kitty.desktop" "${APPS_DIR}/"
cp "${KITTY_APP_DIR}/share/applications/kitty-open.desktop" "${APPS_DIR}/"

echo "Fixing Exec and Icon paths in desktop files"
sed -i "s|Icon=kitty|Icon=$(readlink -f ~)/.local/kitty.app/share/icons/hicolor/256x256/apps/kitty.png|g" "${APPS_DIR}/kitty.desktop" "${APPS_DIR}/kitty-open.desktop"
sed -i "s|Exec=kitty|Exec=$(readlink -f ~)/.local/kitty.app/bin/kitty|g" "${APPS_DIR}/kitty.desktop" "${APPS_DIR}/kitty-open.desktop"

echo "Making kitty the xdg-terminal (if supported)"
echo 'kitty.desktop' >"${CONFIG_DIR}/xdg-terminals.list"

echo "All done. You may need to run 'update-desktop-database' or re-log for menus to refresh."

