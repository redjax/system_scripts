#!/bin/bash

set -e

## Check if httpie is installed
if command -v http &>/dev/null; then
  echo "httpie is already installed: $(http --version)"
  exit 0
fi

## Detect distribution family
if [[ -f /etc/os-release ]]; then
  . /etc/os-release
  DISTRO_ID=${ID,,} # Lowercase
  DISTRO_LIKE=${ID_LIKE,,}
else
  echo "Cannot detect Linux distribution."
  exit 1
fi

## Install httpie based on distribution
if [[ "$DISTRO_ID" == "debian" || "$DISTRO_ID" == "ubuntu" || "$DISTRO_LIKE" == *"debian"* ]]; then
  echo "Detected Debian/Ubuntu family. Installing httpie..."
  sudo apt update
  sudo apt install -y httpie
elif [[ "$DISTRO_ID" == "fedora" || "$DISTRO_ID" == "rhel" || "$DISTRO_ID" == "centos" || "$DISTRO_LIKE" == *"rhel"* || "$DISTRO_LIKE" == *"fedora"* ]]; then
  echo "Detected Red Hat/Fedora family. Installing httpie..."
  if command -v dnf &>/dev/null; then
    sudo dnf install -y httpie
  else
    sudo yum install -y httpie
  fi
else
  echo "Unsupported distribution: $DISTRO_ID"
  exit 2
fi

echo "httpie installation complete: $(http --version)"
