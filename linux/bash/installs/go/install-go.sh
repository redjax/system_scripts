#!/bin/bash

if ! command -v curl >/dev/null 2>&1; then
  echo "[ERROR] curl is not installed"
  exit 1
fi

echo "Downloading Go installer & executing with Bash"
bash <(curl -sL https://git.io/go-installer)
if [[ $? -ne 0 ]]; then
  echo "[ERROR] Failed to install Go."
  exit 1
fi

if [[ -d $HOME/.go ]] && [[ ! -e $HOME/.local/bin/go ]]; then
  mkdir -p "$HOME/.local/bin"
  echo "Creating symlink from ~/.go/bin/go to ~/.local/bin/go to appease VSCode"
  ln -s "$HOME/.go/bin/go" "$HOME/.local/bin/go"
fi

if [[ -d $HOME/.go ]] && [[ ! -e $HOME/.local/bin/gofmt ]]; then
  mkdir -p "$HOME/.local/bin"
  echo "Creating symlink from ~/.go/bin/go to ~/.local/bin/go to appease VSCode"
  ln -s "$HOME/.go/bin/go" "$HOME/.local/bin/go"
fi

echo "Go installed successfully. You might need to add \$HOME/.go/bin to your \$PATH."
exit 0
