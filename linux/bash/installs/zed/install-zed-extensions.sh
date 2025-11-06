#!/usr/bin/env bash
set -uo pipefail

if ! command -v curl &>/dev/null; then
    echo "[ERROR] curl is not installed."
    exit 1
fi

THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

EXTENSIONS_TXT="$THIS_DIR/extensions.txt"
EXTENSIONS_DIR="$HOME/.local/share/zed/extensions/installed"

TMP_DIR="$(mktemp -d)"

function cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

function usage() {
    echo ""
    echo "Usage: ${0} [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help    Show this help message"
    echo ""
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--extensions-file)
            if [[ -z $2 ]] || [[ "$2" == "" ]]; then
                echo "[ERROR] --extensions-file provided, but no file path given."
                exit 1
            fi

            EXTENSIONS_TXT="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "[ERROR] Invalid argument: $1"

            usage
            exit 1
            ;;
    esac
done

if [[ ! -f "$EXTENSIONS_TXT" ]]; then
    echo "[ERROR] Extensions file does not exist: $EXTENSIONS_TXT"
    exit 1
fi

## Create extensions directory if it doesn't exist
mkdir -p "$EXTENSIONS_DIR"

## Read extensions from file into array
mapfile -t extensions < $EXTENSIONS_TXT
echo "Loaded ${#extensions[@]} extension(s) from file: $EXTENSIONS_TXT"

INSTALL_ERRORS=()

for ext in "${extensions[@]}"; do
    echo "Downloading extension: $ext"

    curl -L "https://api.zed.dev/extensions/$ext/download" -o "$TMP_DIR/$ext.tar.gz"
    if [[ $? -ne 0 ]]; then
        echo "[ERROR] Failed downloading extension: $ext"

        INSTALL_ERRORS+=("$ext")
        continue
    fi

    echo "Extracting extension: $ext to $EXTENSIONS_DIR"
    mkdir -p "$EXTENSIONS_DIR/$ext"
    tar -xzf "$TMP_DIR/$ext.tar.gz" -C "$EXTENSIONS_DIR/$ext" --strip-components=1

    echo "Installed extension: $ext"
done

echo "Extensions installed. Restart Zed to load."

if [[ ${#INSTALL_ERRORS[@]} -gt 0 ]]; then
    echo ""
    echo "Failed to install the following extensions:"
    echo "${INSTALL_ERRORS[@]}"
fi
