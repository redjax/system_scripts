#!/usr/bin/env bash
set -uo pipefail

## Check dependencies
for cmd in jq curl uname; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "[ERROR] '$cmd' is not installed."
        exit 1
    fi
done

## Default flags
LATEST=false
LOCAL=false
SIMPLE=false

function usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --latest  Get the latest version of Go"
    echo "  --local   Get the latest version of Go for the current OS/ARCH"
    echo "  --simple  Only print the version number"
    echo ""
}

## Parse command-line arguments
for arg in "$@"; do
    case "$arg" in
        --latest) LATEST=true ;;
        --local) LOCAL=true ;;
        --simple) SIMPLE=true ;;
        -h|--help) usage ; exit 0 ;;
        *) echo "[ERROR] Unknown option: $arg"; usage ; exit 1 ;;
    esac
done

GO_JSON_URL="https://go.dev/dl/?mode=json"

## Fetch JSON
JSON=$(curl -sSL "$GO_JSON_URL")
if [[ $? -ne 0 || -z "$JSON" ]]; then
    echo "[ERROR] Failed to fetch Go versions from $GO_JSON_URL"
    exit 1
fi

## Determine current OS/ARCH
if $LOCAL; then
    OS=$(uname | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64) ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64" ;;
        i386|i686) ARCH="386" ;;
    esac
fi

## Filter JSON
FILTERED_JSON="$JSON"

## Filter for local OS/Arch
if $LOCAL; then
    FILTERED_JSON=$(echo "$FILTERED_JSON" | jq --arg OS "$OS" --arg ARCH "$ARCH" '
        map(
            select(.files | map(select(.os==$OS and .arch==$ARCH)) | length > 0)
            | .files = (.files | map(select(.os==$OS and .arch==$ARCH)))
        )
    ')
fi

## Keep only latest version
if $LATEST; then
    FILTERED_JSON=$(echo "$FILTERED_JSON" | jq 'sort_by(.version) | reverse | .[0:1]')
fi

## Print output
echo "$FILTERED_JSON" | jq -r --arg SIMPLE "$SIMPLE" '
    if $SIMPLE == "true" then
        .[] | .version | sub("^go"; "")
    else
        .[] | 
        .version as $v | 
        "\($v)\n" + (
            .files[] | "  \(.filename) (\(.os)/\(.arch))"
        )
    end
'
