#!/bin/bash

set -e

OS="$(uname -s)"
ARCH="$(uname -m)"

## Detect distro using /etc/os-release
if [ -f /etc/os-release ]; then
  . /etc/os-release
  DISTRO_ID=$ID
else
  echo "Cannot detect Linux distribution."
  exit 1
fi

echo "Detected distro: $DISTRO_ID"

## Install based on distro
case $DISTRO_ID in
  ubuntu | debian)
    echo "deb https://apt.enpass.io/  stable main" | sudo tee /etc/apt/sources.list.d/enpass.list
    wget -O - https://apt.enpass.io/keys/enpass-linux.key | sudo tee /etc/apt/trusted.gpg.d/enpass.asc
    if [[ $? -ne 0 ]]; then
      echo "[ERROR] Failed adding Enpass GPG key."
      exit $?
    fi

    sudo apt-get update -y
    if [[ $? -ne 0 ]]; then
      echo "[ERROR] Failed doing apt update."
      exit $?
    fi

    sudo apt-get install -y enpass
    if [[ $? -ne 0 ]]; then
      echo "[ERROR] Failed installing Enpass."
      exit $?
    fi
    ;;
  fedora)
    cd /etc/yum.repos.d/
    sudo wget https://yum.enpass.io/enpass-yum.repo
    if [[ $? -ne 0 ]]; then
      echo "[ERROR] Failed adding YUM repository for Enpass."
      exit $?
    fi

    sudo dnf install -y enpass
    if [[ $? -ne 0 ]]; then
      echo "[ERROR] Failed installing Enpass."
      exit $?
    fi
    ;;
  *)
    echo "[ERROR] Unsupported distribution: $DISTRO_ID"
    exit 1
    ;;
esac

echo "Enpass installed."
exit 0

