#!/usr/bin/env bash

set -uo pipefail

## Detect architecture
detect_arch() {
    local ARCH
    ARCH=$(uname -m)
    case $ARCH in
        x86_64) echo "x86_64" ;;
        aarch64|arm64) echo "arm64" ;;
        *) echo "Unsupported architecture: $ARCH" >&2; return 1 ;;
    esac
}

## Detect package manager
detect_pkgmgr() {
    if command -v apt >/dev/null 2>&1; then
        echo "apt"
    elif command -v dnf >/dev/null 2>&1; then
        echo "dnf"
    elif command -v yum >/dev/null 2>&1; then
        echo "yum"
    elif command -v zypper >/dev/null 2>&1; then
        echo "zypper"
    elif command -v pacman >/dev/null 2>&1; then
        echo "pacman"
    else
        echo "No supported package manager found" >&2
        return 1
    fi
}

install_official_script() {
    echo "Using official XPipe installation script (recommended)"
    if bash <(curl -sL https://github.com/xpipe-io/xpipe/raw/master/get-xpipe.sh); then
        return 0
    else
        return 1
    fi
}

install_manual() {
    local ARCH=$1
    local PKGMGR=$2
    
    echo "Manual installation for $PKGMGR ($ARCH)"
    
    case $PKGMGR in
        apt)
            if ! wget -q https://github.com/xpipe-io/xpipe/releases/latest/download/xpipe-installer-linux-${ARCH}.deb; then
                echo "Failed to download deb package" >&2
                return 1
            fi
            if ! sudo apt install ./xpipe-installer-linux-${ARCH}.deb; then
                echo "Failed to install deb package" >&2
                return 1
            fi
            rm xpipe-installer-linux-${ARCH}.deb
            ;;
        dnf|yum)
            if ! sudo rpm --import https://xpipe.io/signatures/crschnick.asc; then
                echo "Failed to import GPG key" >&2
                return 1
            fi
            if ! wget -q https://github.com/xpipe-io/xpipe/releases/latest/download/xpipe-installer-linux-${ARCH}.rpm; then
                echo "Failed to download rpm package" >&2
                return 1
            fi
            if ! sudo $PKGMGR install ./xpipe-installer-linux-${ARCH}.rpm; then
                echo "Failed to install rpm package" >&2
                return 1
            fi
            rm xpipe-installer-linux-${ARCH}.rpm
            ;;
        zypper)
            if ! sudo rpm --import https://xpipe.io/signatures/crschnick.asc; then
                echo "Failed to import GPG key" >&2
                return 1
            fi
            if ! wget -q https://github.com/xpipe-io/xpipe/releases/latest/download/xpipe-installer-linux-${ARCH}.rpm; then
                echo "Failed to download rpm package" >&2
                return 1
            fi
            if ! sudo zypper install ./xpipe-installer-linux-${ARCH}.rpm; then
                echo "Failed to install rpm package" >&2
                return 1
            fi
            rm xpipe-installer-linux-${ARCH}.rpm
            ;;
        pacman)
            echo "Arch detected - use AUR helper (yay/paru) or official script recommended"
            echo "Falling back to official script for pacman"
            install_official_script || return 1
            ;;
    esac
    return 0
}

install_portable() {
    local ARCH=$1
    echo "Installing portable version (no package manager needed)"
    if ! wget -q https://github.com/xpipe-io/xpipe/releases/latest/download/xpipe-portable-linux-${ARCH}.tar.gz; then
        echo "Failed to download portable tarball" >&2
        return 1
    fi
    if ! tar -xzf xpipe-portable-linux-${ARCH}.tar.gz; then
        echo "Failed to extract portable tarball" >&2
        return 1
    fi
    echo "Portable XPipe extracted to ./XPipe"
    echo "Run: ./XPipe"
    return 0
}

main() {
    echo "XPipe Linux Universal Installer"
    echo "Detecting system"
    
    local ARCH PKGMGR
    ARCH=$(detect_arch) || { echo "Architecture detection failed" >&2; return 1; }
    PKGMGR=$(detect_pkgmgr) || { echo "Package manager detection failed" >&2; return 1; }
    
    echo "Architecture: $ARCH"
    echo "Package manager: $PKGMGR"
    
    ## Try official script first (handles most cases perfectly)
    if [[ "$PKGMGR" != "pacman" ]]; then
        echo "Attempting official installation script"
        if install_official_script; then
            echo "Installation completed successfully!"
            return 0
        fi
    fi
    
    # Fallback to manual package installation
    echo "Official script failed, trying manual package install"
    if install_manual "$ARCH" "$PKGMGR"; then
        echo "Manual package installation completed!"
        if command -v xpipe >/dev/null 2>&1 && xpipe --version; then
            echo "XPipe verified working!"
        else
            echo "XPipe installed but verification failed"
        fi
        return 0
    fi
    
    # Final fallback: portable
    echo "Package install failed, installing portable version"
    if install_portable "$ARCH"; then
        echo "Portable installation completed!"
        return 0
    fi
    
    echo "All installation methods failed" >&2
    return 1
}

if [[ $EUID -eq 0 ]]; then
    echo "Not recommended to run as root. Continuing"
fi

main "$@"
