#!/usr/bin/env bash

set -euo pipefail

## Define variables
OS="linux"
ARCH="amd64"
INSTALL_DIR="/usr/local/bin"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

## Fetch the latest release version dynamically
VERSION="$(curl -s https://api.github.com/repos/gruntwork-io/terragrunt/releases/latest | grep -oP '"tag_name":\s*"\K(.*)(?=")')"

## Prepare filenames
BINARY_NAME="terragrunt_${OS}_${ARCH}"
BINARY_PATH="${TMP_DIR}/${BINARY_NAME}"
CHECKSUMS_PATH="${TMP_DIR}/SHA256SUMS"

echo "Downloading Terragrunt ${VERSION} for ${OS}/${ARCH}..."
curl -sL "https://github.com/gruntwork-io/terragrunt/releases/download/${VERSION}/${BINARY_NAME}" -o "$BINARY_PATH"

echo "Downloading checksum file..."
curl -sL "https://github.com/gruntwork-io/terragrunt/releases/download/${VERSION}/SHA256SUMS" -o "$CHECKSUMS_PATH"

## Verify checksum
echo "Verifying checksum..."
EXPECTED_CHECKSUM="$(grep "$BINARY_NAME" < "$CHECKSUMS_PATH" | awk '{print $1}')"
ACTUAL_CHECKSUM="$(sha256sum "$BINARY_PATH" | awk '{print $1}')"

if [[ "$EXPECTED_CHECKSUM" == "$ACTUAL_CHECKSUM" ]]; then
    echo "Checksums match for ${VERSION}!"
else
    echo "Checksum verification failed!"
    exit 1
fi

## Remove checksum file
rm -f "$CHECKSUMS_PATH"

## Install Terragrunt
echo "Installing Terragrunt to ${INSTALL_DIR}..."
sudo install -m 0755 "$BINARY_PATH" "${INSTALL_DIR}/terragrunt"

echo "Terragrunt ${VERSION} installed successfully at $(command -v terragrunt)"
