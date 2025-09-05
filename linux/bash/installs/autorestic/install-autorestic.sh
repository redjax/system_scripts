#!/bin/bash

set -euo pipefail

WGET_INSTALLED=""
CURL_INSTALLED=""

if command -v autorestic >/dev/null 2>&1; then
    echo "autorestic is already installed."
    exit 0
fi

if command -v wget >/dev/null 2>&1; then
    WGET_INSTALLED="true"
fi

if command -v curl >/dev/null 2>&1; then
    CURL_INSTALLED="true"
fi

if [[ "$WGET_INSTALLED" == "" ]] && [[ "$CURL_INSTALLED" == "" ]]; then
    echo "[ERROR] Missing both wget & curl. Install one or both and try again."
    exit 1
fi

if [[ "$WGET_INSTALLED" == "true" ]]; then
    echo "Installing autorestic"
    wget -qO - https://raw.githubusercontent.com/cupcakearmy/autorestic/master/install.sh | sudo bash
    
    if [[ $? -ne 0 ]]; then
        echo "[ERROR] Failed to install autorestic."
    fi
elif [[ "$CURL_INSTALLED" == "true" ]]; then
    echo "Installing autorestic"
    curl -LsSf https://raw.githubusercontent.com/cupcakearmy/autorestic/master/install.sh | sudo bash
    
    if [[ $? -ne 0 ]]; then
        echo "[ERROR] Failed to install autorestic."
    fi
fi

echo "autorestic installed."
