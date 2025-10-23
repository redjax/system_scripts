#!/usr/bin/env bash

set -uo pipefail

if ! command -v curl &>/dev/null; then
  echo "[ERROR] curl is not installed."
  exit 1
fi

echo "Installing atuin"
echo ""

curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh

if [[ $? -ne 0 ]]; then
  echo "[ERROR] Failed installing atuin."
  exit $?
else
  echo "Atuin is installed."
fi

while true; do
  read -n 1 -r -p "Register/login to sync encrypted history? (y/n): " yn
  echo ""

  case $yn in
  [Yy])
    read -n 1 -r -p "Atuin username (new or existing): " atuinUser
    echo ""
    read -n 1 -r -p "Email address: " atuinEmail
    echo ""

    atuin register -u $atuinUser -e atuinEmail
    echo ""

    echo "See your encryption key with 'atuin key'. Make a backup of this!"

    break
    ;;
  [Nn])
    break
    ;;
  esac
done
