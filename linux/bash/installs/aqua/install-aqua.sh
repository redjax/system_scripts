#!/usr/bin/env bash
set -eu -o pipefail

AQUA_ROOT_DIR="${AQUA_ROOT_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/aquaproj-aqua}"
AQUA_INSTALLER_URL="https://raw.githubusercontent.com/aquaproj/aqua-installer/main/aqua-installer"

echo ""
echo "Installing latest aqua to $AQUA_ROOT_DIR"
echo ""

## Download and run aqua-installer (automatically fetches latest aqua)
curl -sSfL "$AQUA_INSTALLER_URL" | AQUA_ROOT_DIR="$AQUA_ROOT_DIR" bash

## Update PATH for current session
export PATH="$AQUA_ROOT_DIR/bin:$PATH"

echo "aqua installed. Add the following to your ~/.bashrc:"
echo '  export PATH="${AQUA_ROOT_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/aquaproj-aqua}/bin:\$PATH"'

## Verify installation
if command -v aqua >/dev/null 2>&1; then
    echo "Success: $(aqua version)"
else
    echo "[ERROR] Failed installing aqua."
    exit 1
fi
