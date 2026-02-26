#!/usr/bin/env bash
set -uo pipefail

## Configuration
REPO="zyedidia/micro"
INSTALL_DIR="$HOME/.local/bin"
TMP_DIR="/tmp/micro-install-$$"

## Function to detect platform
detect_platform() {
    local os arch platform

    os="$(uname -s)"
    arch="$(uname -m)"

    case "$os" in
        Linux)
            case "$arch" in
                x86_64)
                    platform="linux64"
                    ;;
                aarch64|arm64)
                    platform="linux-arm64"
                    ;;
                armv7l|armv6l)
                    platform="linux-arm"
                    ;;
                i686|i386)
                    platform="linux32"
                    ;;
                *)
                    echo "[ERROR] Unsupported architecture: $arch"
                    exit 1
                    ;;
            esac
            ;;
        Darwin)
            case "$arch" in
                x86_64)
                    platform="osx"
                    ;;
                arm64)
                    platform="osx-arm64"
                    ;;
                *)
                    echo "[ERROR] Unsupported architecture: $arch"
                    exit 1
                    ;;
            esac
            ;;
        *)
            echo "[ERROR] Unsupported operating system: $os"
            exit 1
            ;;
    esac

    echo "$platform"
}

## Function to get the latest release tag from Github
get_latest_release() {
    local latest_tag

    echo "Fetching latest release information from GitHub..." >&2
    
    if command -v curl >/dev/null 2>&1; then
        latest_tag=$(curl -sL "https://api.github.com/repos/$REPO/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    elif command -v wget >/dev/null 2>&1; then
        latest_tag=$(wget -qO- "https://api.github.com/repos/$REPO/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    else
        echo "[ERROR] Neither curl nor wget is available. Please install one of them." >&2
        exit 1
    fi

    if [ -z "$latest_tag" ]; then
        echo "[ERROR] Failed to fetch latest release tag" >&2
        exit 1
    fi

    echo "$latest_tag"
}

## Function to get current installed version
get_installed_version() {
    if command -v micro >/dev/null 2>&1; then
        micro -version 2>&1 | head -n1 | awk '{print $3}'
    else
        echo ""
    fi
}

## Function to download and install micro
install_micro() {
    local platform="$1"
    local version="$2"
    local version_number="${version#v}"
    local download_url="https://github.com/$REPO/releases/download/$version/micro-$version_number-$platform.tar.gz"
    local tarball="$TMP_DIR/micro.tar.gz"

    ## Create temporary directory
    mkdir -p "$TMP_DIR"

    echo "Downloading micro $version for $platform"
    echo "Download URL: $download_url"

    if command -v curl >/dev/null 2>&1; then
        if ! curl -fSL --progress-bar "$download_url" -o "$tarball"; then
            echo "[ERROR] Download failed!"
            cleanup
            exit 1
        fi
    elif command -v wget >/dev/null 2>&1; then
        if ! wget --show-progress -O "$tarball" "$download_url"; then
            echo "[ERROR] Download failed!"
            cleanup
            exit 1
        fi
    fi

    echo "Extracting micro"
    tar -xzf "$tarball" -C "$TMP_DIR"

    ## Create install directory if it doesn't exist
    mkdir -p "$INSTALL_DIR"

    echo "Installing micro to $INSTALL_DIR"
    
    ## Find the micro binary in the extracted files
    local micro_binary=$(find "$TMP_DIR" -name "micro" -type f | head -n1)
    
    if [ -z "$micro_binary" ]; then
        echo "[ERROR] Could not find micro binary in the extracted archive"
        cleanup
        exit 1
    fi

    ## Install the binary
    cp "$micro_binary" "$INSTALL_DIR/micro"
    chmod +x "$INSTALL_DIR/micro"

    echo "Cleaning up temporary files"
    cleanup

    echo "micro $version installed successfully!"
    
    ## Check if install directory is in PATH
    if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
        echo "[WARN] $INSTALL_DIR is not in your PATH"
        echo "[WARN] Add the following line to your ~/.bashrc or ~/.zshrc:"
        echo ""
        echo "    export PATH=\"\$PATH:$INSTALL_DIR\""
        echo ""
    fi
}

## Function to cleanup temporary files
cleanup() {
    if [ -d "$TMP_DIR" ]; then
        rm -rf "$TMP_DIR"
    fi
}

## Trap to ensure cleanup on exit
trap cleanup EXIT

main() {
    echo "Micro Editor Installer/Updater"
    echo ""

    ## Check for required tools
    if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
        echo "[ERROR] Neither curl nor wget is installed. Please install one of them."
        exit 1
    fi

    if ! command -v tar >/dev/null 2>&1; then
        echo "[ERROR] tar is not installed. Please install it."
        exit 1
    fi

    ## Detect platform
    platform=$(detect_platform)
    echo "Detected platform: $platform"

    ## Get latest release
    latest_version=$(get_latest_release)
    echo "Latest version: $latest_version"

    ## Check if already installed
    installed_version=$(get_installed_version)
    
    if [ -n "$installed_version" ]; then
        echo "Currently installed version: $installed_version"
        
        if [ "$installed_version" = "$latest_version" ] || [ "v$installed_version" = "$latest_version" ]; then
            echo "You already have the latest version installed!"
            read -p "Do you want to reinstall? [y/N] " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo "Installation cancelled."
                exit 0
            fi
        else
            echo "Upgrading from $installed_version to $latest_version"
        fi
    fi

    ## Install micro
    install_micro "$platform" "$latest_version"
    
    ## Verify installation
    if command -v micro >/dev/null 2>&1; then
        echo "Verification: $(micro -version 2>&1 | head -n1)"
    else
        echo "[WARN] micro command not found. You may need to restart your shell or add $INSTALL_DIR to your PATH."
    fi
}

main
