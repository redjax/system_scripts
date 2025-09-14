#!/bin/bash

if command -v lazydocker &>/dev/null; then
  echo "Lazydocker is already installed."
  read -p "Run anyway (this will update the app if there is an available update)? (y/n): " update
  
  case $update in
    [Yy]* )
      echo "Continuing with Lazydocker install."
      ;;
    [Nn]* )
      echo "Exiting."
      exit 0
      ;;
    *)
      echo "Invalid answer: $1"
      exit 1
      ;;
  esac
fi

if ! command -v curl &>/dev/null; then
  echo "[ERROR] curl is not installed."
  exit 1
fi

echo "Installing Lazydocker"

curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash

if [[ $? -ne 0 ]]; then
  echo "[ERROR] Failed installing Lazydocker"
  exit 1
else
  echo "Installed Lazydocker"
  exit 0
fi

