#!/usr/bin/env bash
set -euo pipefail

if ! command -v curl &>/dev/null; then
    echo "curl is not installed."
    exit 1
fi
if ! command -v unzip &>/dev/null; then
    echo "unzip is not installed."
    exit 1
fi

OS="$(uname -s)"
ARCH="$(uname -m)"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

case "$OS" in
Linux)
    PLATFORM="unknown-linux-gnu"
    ;;
Darwin)
    PLATFORM="apple-darwin"
    ;;
*)
    echo "Unsupported OS: $OS"
    exit 1
    ;;
esac

if [[ "$ARCH" == "x86_64" ]]; then
    ARCH="x86_64"
elif [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
    ARCH="aarch64"
else
    echo "Unsupported architecture: $ARCH"
    exit 1
fi

# Detect if Debian-based (for adding debian.griffo.io repo)
IS_DEBIAN=0
if [[ -f /etc/os-release ]]; then
   . /etc/os-release
   ID_LIKE="${ID_LIKE:-}"
   if [[ "$ID" == "debian" || "$ID_LIKE" == *"debian"* ]]; then
       IS_DEBIAN=1
   fi
fi

if [[ "$IS_DEBIAN" -eq 1 ]]; then
    echo "Detected Debian-based system. Installing Yazi from debian.griffo.io repo..."

    # Add GPG key
    curl -sS https://debian.griffo.io/EA0F721D231FDD3A0A17B9AC7808B4DD62C41256.asc | sudo gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/debian.griffo.io.gpg

    # Add repository to sources list
    echo "deb https://debian.griffo.io/apt $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/debian.griffo.io.list

    sudo apt-get update

    # Install yazi and dependencies from repo
    sudo apt-get install -y yazi

else
    # Fallback: install from GitHub release zip

    LATEST_JSON=$(curl -s https://api.github.com/repos/sxyazi/yazi/releases/latest)
    ASSET="yazi-${ARCH}-${PLATFORM}.zip"
    ASSET_URL=$(echo "$LATEST_JSON" | grep "browser_download_url" | grep "${ASSET}" | sed -E 's/.*"(https:[^"]+)".*/\1/')

    if [[ -z "$ASSET_URL" ]]; then
        echo "Could not find release asset for $ARCH-$PLATFORM"
        exit 1
    fi

    echo "Downloading $ASSET_URL to $TMPDIR/$ASSET"
    curl -L -o "$TMPDIR/$ASSET" "$ASSET_URL"

    echo "Extracting $ASSET in $TMPDIR"
    unzip -q -o "$TMPDIR/$ASSET" -d "$TMPDIR"

    YAZI_BIN=$(find "$TMPDIR" -type f -name "yazi" | head -n 1)
    YA_BIN=$(find "$TMPDIR" -type f -name "ya" | head -n 1)

    if [[ -z "$YAZI_BIN" ]]; then
        echo "ERROR: 'yazi' binary not found after extraction."
        exit 1
    fi

    if [[ -z "$YA_BIN" ]]; then
        echo "ERROR: 'ya' binary not found after extraction."
        exit 1
    fi

    chmod +x "$YAZI_BIN" "$YA_BIN"
    echo "Moving binaries to /usr/local/bin/"
    sudo mv "$YAZI_BIN" /usr/local/bin/yazi
    sudo mv "$YA_BIN" /usr/local/bin/ya
    echo "Binaries installed to /usr/local/bin/"
fi

# Handle completions directory if exists
COMPLETIONS_DIR=$(find "$TMPDIR" -type d -name "completions" | head -n 1)

if [[ -z "$COMPLETIONS_DIR" ]]; then
    echo "No completions directory found in extracted archive."
else
    USER_SHELL="$(basename "$SHELL")"
    case "$USER_SHELL" in
    bash)
        COMPLETION_SRC="$COMPLETIONS_DIR/yazi.bash"
        if [[ $EUID -eq 0 ]]; then
            COMPLETION_DEST="/usr/share/bash-completion/completions/yazi"
        else
            COMPLETION_DEST="${XDG_DATA_HOME:-$HOME/.local/share}/bash-completion/completions/yazi"
            mkdir -p "$(dirname "$COMPLETION_DEST")"
        fi
        if [[ -f "$COMPLETION_SRC" ]]; then
            cp "$COMPLETION_SRC" "$COMPLETION_DEST"
            echo "Bash completion installed to $COMPLETION_DEST"
        else
            echo "Bash completion script not found at $COMPLETION_SRC"
        fi
        ;;
    zsh)
        COMPLETION_SRC="$COMPLETIONS_DIR/yazi.zsh"
        COMPLETION_DEST="$HOME/.zsh/completions/_yazi"
        mkdir -p "$(dirname "$COMPLETION_DEST")"
        if [[ -f "$COMPLETION_SRC" ]]; then
            cp "$COMPLETION_SRC" "$COMPLETION_DEST"
            echo "Zsh completion installed to $COMPLETION_DEST"
            echo "Ensure this directory is in your fpath, e.g. add in your .zshrc:"
            echo "  fpath+=\$HOME/.zsh/completions"
        else
            echo "Zsh completion script not found at $COMPLETION_SRC"
        fi
        ;;
    fish)
        COMPLETION_SRC="$COMPLETIONS_DIR/yazi.fish"
        COMPLETION_DEST="$HOME/.config/fish/completions/yazi.fish"
        mkdir -p "$(dirname "$COMPLETION_DEST")"
        if [[ -f "$COMPLETION_SRC" ]]; then
            cp "$COMPLETION_SRC" "$COMPLETION_DEST"
            echo "Fish completion installed to $COMPLETION_DEST"
        else
            echo "Fish completion script not found at $COMPLETION_SRC"
        fi
        ;;
    *)
        echo "Shell $USER_SHELL not recognized for completions."
        echo "Please install completions manually."
        ;;
    esac
fi
