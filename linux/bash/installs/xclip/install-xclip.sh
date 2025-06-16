#!/bin/bash

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
PARENT_DIR="$(dirname "$SCRIPT_PATH")"

function install_xclip {
    if command -v xclip 2>&1 > /dev/null; then
        echo "xclip is already installed."
        return 0
    fi

    echo "Installing xclip"
    sudo apt install -y xclip
    if [[ $? -ne 0 ]]; then
        echo "[ERROR] Failed to install xclip"
        return 1
    fi

    echo "xclip installed"
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  install_xclip "$@"
  if [[ $? -ne 0 ]]; then
    echo "Failed to install xclip"
    exit 1
  fi
fi
