#!/bin/bash

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
PARENT_DIR="$(dirname "$SCRIPT_PATH")"

function install_tpm {
  if [[ -d ~/.tmux/plugins/tpm ]]; then
    echo "tpm is already installed."
    return 0
  fi

  if ! command -v git --version > /dev/null 2>&1 ; then
    echo "[ERROR] git is not installed."
    return 1
  fi

  echo "Cloning tpm repository"
  git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
  if [[ $? -ne 0 ]]; then
    echo "[ERROR] error wwhile cloning tpm repository to ~/.tmux/plugins/tpm"
    return 1
  fi

  echo "tpm cloned to ~/.tmux/plugins/tpm. Next time you open tmux, use CTRL+b i to install."
  return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  install_tpm "$@"
  if [[ $? -ne 0 ]]; then
    echo "Failed to install tpm"
    exit 1
  fi
fi
