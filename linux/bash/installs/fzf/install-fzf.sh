#!/bin/bash

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
PARENT_DIR="$(dirname "$SCRIPT_PATH")"

function install_fzf {
    if command -v fzf 2>&1 > /dev/null; then
        echo "fzf is already installed."
        return 0
    fi

    echo "Installing fzf"
    sudo apt install -y fzf
    if [[ $? -ne 0 ]]; then
        echo "[ERROR] Failed to install fzf"
        return 1
    fi

    echo "fzf installed"
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  install_fzf "$@"
  if [[ $? -ne 0 ]]; then
    echo "Failed to install fzf"
    exit 1
  fi
fi
