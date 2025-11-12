#!/bin/bash

set -uo pipefail

VERSION=""

## Parse args
while (( "$#" )); do
  case "$1" in
    -v|--version)
      if [ -n "$2" ] && [ "${2:0:1}" != "-" ]; then
        VERSION=$2
        shift 2
      else
        echo "Error: Argument for $1 is missing" >&2
        exit 1
      fi
      ;;
    *) # preserve positional arguments
      PARAMS="$PARAMS $1"
      shift
      ;;
  esac
done

if ! command -v curl >/dev/null 2>&1; then
  echo "[ERROR] curl is not installed"
  exit 1
fi

echo "Downloading Go installer & executing with Bash"
if [ -n "$VERSION" ]; then
  echo "Installing Go version $VERSION"
  bash <(curl -sL https://git.io/go-installer) --version "$VERSION"
else
  echo "Installing latest Go version"
  bash <(curl -sL https://git.io/go-installer)
fi

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
  echo "Creating symlink from ~/.go/bin/gofmt to ~/.local/bin/gofmt to appease VSCode"
  ln -s "$HOME/.go/bin/gofmt" "$HOME/.local/bin/gofmt"
fi

echo "Go installed successfully. You might need to add \$HOME/.go/bin to your \$PATH."
exit 0
