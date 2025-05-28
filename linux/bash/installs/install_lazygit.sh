#!/bin/bash

if command -v lazygit 2>&1 /dev/null; then
    echo "Lazygit is already installed."
    exit 1
fi

if ! command -v curl 2>&1 /dev/null; then
    echo "curl is not installed. Install curl before continuing"
    exit 1
fi

if ! command -v tar 2>&1 /dev/null; then
    echo "tar is not installed. Install tar before continuing"
    exit 1
fi

echo "-- [ Install Lazygit"

LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | \grep -Po '"tag_name": *"v\K[^"]*')
if [[ $? -ne 0 ]]; then
    echo "Failed to retrieve current Lazygit version"
    exit 1
fi

## Get CPU architecture
CPU_ARCH=$(uname -m)

## Select CPU architecture for curl request
case "$CPU_ARCH" in
    x86_64)
        LAZYGIT_ARCH="x86_64"
    ;;
    aarch64 | arm64)
        LAZYGIT_ARCH="arm64"
    ;;
    *)
        echo "Unsupported CPU architecture: $CPU_ARCH"
        exit 1
    ;;
esac

echo "Downloading Lazygit v${LAZYGIT_VERSION} (CPU arch: $LAZYGIT_ARCH)"
curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_${LAZYGIT_ARCH}.tar.gz"
if [[ $? -ne 0 ]]; then
    echo "Failed to download lazygit.tar.gz from Github repository."
    exit 1
fi

echo "Extracting Lazygit"
tar xf lazygit.tar.gz lazygit
if [[ $? -ne 0 ]]; then
    echo "Failed to extract lazygit"
fi

echo "Installing lazygit to /usr/local/bin"
sudo install lazygit -D -t /usr/local/bin
if [[ $? -ne 0 ]]; then
    echo "Failed to install lazygit"
    exit 1
else
    echo "Lazygit installed. Executing `lazygit --version` as a test"
    lazygit --version
    if [[ $? -ne 0 ]]; then
        echo "Lazygit command failed. Try reloading your session by running exec \$SHELL, or logging out and back in. Then run `lazygit --version manually`"
        exit $?
    fi
fi

