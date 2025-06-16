#!/bin/bash

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
PARENT_DIR="$(dirname "$SCRIPT_PATH")"

function install_lazygit {
  if command -v lazygit --version 2>&1 > /dev/null; then
    echo "Lazygit is already installed."
    return 0
  fi

  if ! command -v git --version > /dev/null 2>&1 ; then
    echo "[ERROR] git is not installed."
    return 1
  fi

  if ! command -v curl --version > /dev/null 2>&1 ; then
    echo "[ERROR] curl is not installed."
    return 1
  fi

  if ! command -v tar --version > /dev/null 2>&1 ; then
    echo "[ERROR] tar is not installed."
    return 1
  fi

  echo "Installing Lazygit"
  LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | \grep -Po '"tag_name": *"v\K[^"]*')
  curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
  tar xf lazygit.tar.gz lazygit
  sudo install lazygit -D -t /usr/local/bin/

  ## Cleanup
  if [[ -f lazygit.tar.gz ]]; then
    rm lazygit.tar.gz
  fi

  if [[ -f lazygit ]]; then
    rm lazygit
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  install_lazygit "$@"
  if [[ $? -ne 0 ]]; then
    echo "Failed to install lazygit"
    exit 1
  fi
fi
