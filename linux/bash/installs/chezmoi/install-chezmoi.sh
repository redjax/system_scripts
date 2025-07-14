#!/bin/bash

if ! command -v curl &>/dev/null; then
  echo "curl is not installed. Please install curl & try again."
  exit 1
fi

echo "Downloading & executing Chezmoi install script."
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b $HOME/.local/bin
if [[ $? -ne 0 ]]; then
  echo "Failed installing chezmoi."
  exit $?
else
  echo "Chezmoi installed successfully. You might need to add \$HOME/.local/bin to your \$PATH."
  exit 0
fi

