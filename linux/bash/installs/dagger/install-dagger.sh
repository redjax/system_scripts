#!/bin/bash

curl -fsSL https://dl.dagger.io/dagger/install.sh | BIN_DIR=$HOME/.local/bin sh
if [[ $? -ne 0 ]]; then
  echo "[ERROR] Failed installing dagger"
  exit $?
fi

if [[ ! -f $HOME/.local/bin/dagger ]]; then
  echo "[ERROR] Curl command ran successfully, but dagger is not in $HOME/.local/bin."
  echo "  If this script was run with sudo, it will be in /usr/local/bin"
echo "Dagger installed to $HOME/.local/bin"
echo ""
echo "You may need to add 'export PATH=\$PATH:\$HOME/.local/bin' to your ~/.bashrc file"
exit 0

