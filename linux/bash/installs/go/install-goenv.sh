#!/usr/bin/env bash

set -uo pipefail

if ! command -v git &>/dev/null; then
    echo "[ERROR] git is not installed."
    exit 1
fi

GOENV_ROOT="$HOME/.goenv"

## Create a temporary directory
TMP_DIR=$(mktemp -d -t goenv-install-XXXXXX)
if [[ ! "$TMP_DIR" || ! -d "$TMP_DIR" ]]; then
    echo "[ERROR] Could not create temporary directory"
    exit 1
fi

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

echo "Cloning goenv repository into temporary directory $TMP_DIR"
git clone --quiet https://github.com/go-nv/goenv.git "$TMP_DIR" || {
    echo "[ERROR] Failed to clone goenv repository"
    exit 1
}

## Remove existing installation if any
if [ -d "$GOENV_ROOT" ]; then
    echo "Removing existing goenv installation at $GOENV_ROOT"
    rm -rf "$GOENV_ROOT"
fi

echo "Moving goenv from temporary directory to $GOENV_ROOT"
mv "$TMP_DIR" "$GOENV_ROOT" || {
    echo "[ERROR] Failed to move goenv directory"
    exit 1
}

## Disable cleanup trap since directory moved
trap - EXIT

echo "goenv installed to $GOENV_ROOT"
echo ""

echo "Remember to add goenv init to your shell configuration."
echo "  echo 'export GOENV_ROOT=\"\$HOME/.goenv\"' >> ~/.bash_profile"
echo "  echo 'export PATH=\"\$GOENV_ROOT/bin:\$PATH\"' >> ~/.bash_profile"

echo ""
echo "Also add this to your .bashrc/.zshrc:"
echo "  eval \"\$(goenv init -)\""
