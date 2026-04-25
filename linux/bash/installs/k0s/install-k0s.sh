#!/usr/bin/env bash

set -uo pipefail

if command -v k0s &>/dev/null; then
  echo "k0s is already installed."
  
  while true; do
    read -n 1 -r -p "Proceed anyway? (y/n)" yn

    case $yn in
    [Yy]*)
      echo ""
      break
      ;;
    [Nn]*)
      echo "Exiting"
      exit 0
      ;;
    esac
  done
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "[ERROR] curl is not installed"
  exit 1
fi

echo "Downloading k0s installer & executing with Bash"
curl -sSLf https://get.k0s.sh | sudo sh
if [[ $? -ne 0 ]]; then
  echo "[ERROR] Failed to install k0s."
  exit 1
else
  echo "k0s installed successfully."
fi

while true; do
  read -n 1 -r -p "Start a controller node? (y/n)" yn

  case $yn in
  [Yy]*)
    echo ""
    echo "Installing k0s controller"

    sudo k0s install controller --single
    if [[ $? -ne 0 ]]; then
      echo "[ERROR] Failed to install k0s controller."
      exit 1
    fi

    break

    ;;
  [Nn]*)
    echo ""
    break
    ;;
  esac
done

while true; do
  read -n 1 -r -p "Start a worker node? (y/n)" yn

  case $yn in
  [Yy]*)
    echo ""
    echo "Installing k0s worker"

    sudo k0s install worker --single
    if [[ $? -ne 0 ]]; then
      echo "[ERROR] Failed to install k0s worker."
      exit 1
    fi

    break

    ;;
  [Nn]*)
    echo ""
    break
    ;;
  esac
done

while true; do
  read -n 1 -r -p "Start k0s? (y/n)" yn

  case $yn in
  [Yy]*)
    echo ""
    echo "Starting k0s"

    sudo k0s start
    if [[ $? -ne 0 ]]; then
      echo "[ERROR] Failed to start k0s."
      exit 1
    fi

    ;;
  [Nn]*)
    echo ""
    break
    ;;
  esac
done
