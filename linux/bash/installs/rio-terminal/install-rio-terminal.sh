#!/usr/bin/env bash
set -uo pipefail

function install_rio_themes() {
    local TMPDIR="${TMPDIR:-$(mktemp -d)}"
    echo "Cloning rio-themes repo..."
    git clone https://github.com/raphamorim/rio-terminal-themes "$TMPDIR/rio-terminal-themes"
    if [[ $? -ne 0 ]]; then
        echo "[ERROR] Failed to clone rio-themes repo."
        return 1
    fi

    mkdir -p ~/.config/rio/themes
    # Use cp -r to copy themes contents, overwrite existing safely
    cp -r "$TMPDIR/rio-terminal-themes/themes/." ~/.config/rio/themes/

    # Clean up cloned repo
    rm -rf "$TMPDIR/rio-terminal-themes"

    echo "Rio themes installed successfully!"
    return 0
}

if ! command -v curl &>/dev/null; then
    echo "curl is not installed."
    exit 1
fi

if ! command -v git &>/dev/null; then
    echo "git is not installed."
    exit 1
fi

TMPDIR="${TMPDIR:-$(mktemp -d)}"
echo "TMPDIR: $TMPDIR"

OS="$(uname -s)"
ARCH="$(uname -m)"
echo "OS: $OS ARCH: $ARCH"

if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO_ID=$ID
else
    echo "Cannot detect Linux distribution."
    exit 1
fi
echo "Detected distro: $DISTRO_ID"

SESSION_MANAGER="${XDG_SESSION_TYPE:-x11}"
echo "Detected session manager: $SESSION_MANAGER"

if [[ "$SESSION_MANAGER" != "wayland" && "$SESSION_MANAGER" != "x11" ]]; then
    echo "Unsupported session manager: $SESSION_MANAGER"
    exit 1
fi

RIO_VERSION="$(curl -s https://api.github.com/repos/raphamorim/rio/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')"
if [[ -z "$RIO_VERSION" ]]; then
    echo "[ERROR] Could not fetch latest version."
    exit 1
fi
RIO_VERSION="${RIO_VERSION#v}"

echo "Installing Rio terminal v${RIO_VERSION}"

# Select asset based on OS, Arch, Distro
if [ "$OS" = "Linux" ]; then
    case "$ARCH" in
    x86_64 | amd64)
        if [[ "$DISTRO_ID" == "debian" || "$DISTRO_ID" == "ubuntu" ]]; then
            FILE="rioterm_${RIO_VERSION}_amd64_${SESSION_MANAGER}.deb"
        elif [[ "$DISTRO_ID" == "fedora" || "$DISTRO_ID" == "rhel" || "$DISTRO_ID" == "centos" ]]; then
            FILE="rioterm-${RIO_VERSION}-1.x86_64_${SESSION_MANAGER}.rpm"
        else
            echo "Unsupported Linux distribution: $DISTRO_ID"
            exit 1
        fi
        ;;
    aarch64 | arm64)
        if [[ "$DISTRO_ID" == "debian" || "$DISTRO_ID" == "ubuntu" ]]; then
            FILE="rioterm_${RIO_VERSION}_arm64_${SESSION_MANAGER}.deb"
        elif [[ "$DISTRO_ID" == "fedora" || "$DISTRO_ID" == "rhel" || "$DISTRO_ID" == "centos" ]]; then
            FILE="rioterm-${RIO_VERSION}-1.aarch64_${SESSION_MANAGER}.rpm"
        else
            echo "Unsupported Linux distribution: $DISTRO_ID"
            exit 1
        fi
        ;;
    *)
        echo "Unsupported Linux architecture: $ARCH"
        exit 1
        ;;
    esac
elif [ "$OS" = "Darwin" ]; then
    FILE="rio.dmg"
else
    echo "Unsupported OS: $OS"
    exit 1
fi

URL="https://github.com/raphamorim/rio/releases/download/v${RIO_VERSION}/$FILE"
ARCHIVE="$TMPDIR/$FILE"

echo "Downloading $FILE from $URL"
curl -L -o "$ARCHIVE" "$URL"

if [[ "$OS" == "Darwin" ]]; then
    unzip -o "$ARCHIVE" -d "$TMPDIR"
    BIN_PATH=$(find "$TMPDIR" -type f -name 'rio' | head -n 1)
    if [ -z "$BIN_PATH" ]; then
        echo "rio binary not found in archive."
        exit 1
    fi
    sudo install -m 755 "$BIN_PATH" /usr/local/bin/
elif [[ "$OS" == "Linux" ]]; then
    if [[ "$FILE" =~ \.rpm$ ]]; then
        echo "Installing RPM package (requires sudo)"
        sudo rpm -i --replacepkgs "$ARCHIVE"
    elif [[ "$FILE" =~ \.deb$ ]]; then
        echo "Installing DEB package (requires sudo)"
        sudo dpkg -i "$ARCHIVE"
    else
        echo "Unknown Linux asset type: $FILE"
        exit 1
    fi
fi

echo "Rio installed successfully!"

echo ""
read -p "Install Rio themes from the https://github.com/raphamorim/rio-terminal-themes repo? (y/n) " -n 1 -r
echo ""

case $REPLY in
[Yy]*)
    install_rio_themes
    if [[ $? -ne 0 ]]; then
        echo "[ERROR] Failed to install rio themes."
        exit 1
    fi
    exit 0
    ;;
*)
    echo "Skipping themes download."
    exit 0
    ;;
esac
