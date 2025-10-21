#!/bin/bash

if ! command -v curl &> /dev/null; then
    echo "curl could not be found, please install curl first."
    exit 1
fi

arch=$(uname -m)

if [[ "$arch" == "x86_64" ]]; then
  echo "Detected AMD/Intel CPU architecture (amd64)."
  echo ""
  echo "Installing devpod for AMD64"

  curl -L -o devpod "https://github.com/loft-sh/devpod/releases/latest/download/devpod-linux-amd64"
  if [[ $? -ne 0 ]]; then
    echo "Failed to download devpod binary."
    exit 1
  fi
  
  sudo install -c -m 0755 devpod /usr/local/bin
  if [[ $? -ne 0 ]]; then
    echo "Failed to install devpod binary."
    rm -f devpod
    exit 1
  fi

  rm -f devpod
elif [[ "$arch" == "aarch64" ]]; then
  echo "Detected ARM64 CPU architecture."
  echo ""
  echo "Installing devpod for ARM64"
  
  curl -L -o devpod "https://github.com/loft-sh/devpod/releases/latest/download/devpod-linux-arm64"
  if [[ $? -ne 0 ]]; then
    echo "Failed to download devpod binary."
    exit 1
  fi
  
  sudo install -c -m 0755 devpod /usr/local/bin
  if [[ $? -ne 0 ]]; then
    echo "Failed to install devpod binary."
    rm -f devpod
    exit 1
  fi
  
  rm -f devpod
else
  echo "Unsupported CPU architecture: $arch"
  exit 1
fi
