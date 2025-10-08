#!/usr/bin/env bash
set -euo pipefail

# Detect OS and Linux distribution
OS=$(uname -s)
DISTRO=""
PACKAGE_INSTALL_CMD=""

if [[ "$OS" == "Darwin" ]]; then
    PM="brew"
elif [[ "$OS" == "Linux" ]]; then
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
        case "$DISTRO" in
        ubuntu | debian)
            PM="apt-get"
            ;;
        fedora | centos | rhel)
            PM="dnf"
            ;;
        arch)
            PM="pacman"
            ;;
        opensuse* | suse)
            PM="zypper"
            ;;
        *)
            echo "Unsupported or unknown Linux distribution: $DISTRO"
            exit 1
            ;;
        esac
    else
        echo "Cannot detect Linux distribution"
        exit 1
    fi
else
    echo "Unsupported OS: $OS"
    exit 1
fi

# Install dependencies functions per OS/distro
install_mac() {
    # Install Homebrew if missing
    if ! command -v brew &>/dev/null; then
        echo "Homebrew not found, installing..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi

    echo "Updating Homebrew..."
    brew update

    echo "Installing dependencies on macOS via Homebrew..."
    brew install ffmpeg jq poppler fd ripgrep fzf zoxide resvg imagemagick xclip || true
    # 7-Zip on macOS via brew is "p7zip"
    brew install p7zip || true

    # Nerd Fonts via Homebrew Cask Fonts
    brew tap homebrew/cask-fonts
    # Install a popular nerd font; user can customize this if needed
    brew install --cask font-hack-nerd-font

    echo "Dependencies installed on macOS."
}

install_debian() {
    sudo apt-get update
    sudo apt-get install -y ffmpeg jq poppler-utils fd-find ripgrep fzf zoxide rsync imagemagick xclip p7zip-full unzip curl fontconfig || true

    # Nerd Fonts installer script
    if ! fc-list | grep -qi nerd; then
        echo "Installing Nerd Fonts on Debian via manual script..."
        curl -fsSL https://raw.githubusercontent.com/monoira/nefoin/main/install.sh | bash -s -- "FiraCode"
        fc-cache -fv
    fi

    echo "Dependencies installed on Debian/Ubuntu."
}

install_fedora() {
    sudo dnf install -y ffmpeg jq poppler-utils fd-find ripgrep fzf zoxide rsync ImageMagick xclip p7zip-full unzip curl fontconfig || true

    # Nerd Fonts manual installation as Fedora doesn't package Nerd Fonts
    fc-list | grep -qi nerd || {
        echo "Installing Nerd Fonts on Fedora via manual script..."
        curl -fsSL https://raw.githubusercontent.com/monoira/nefoin/main/install.sh | bash -s -- "FiraCode"
        fc-cache -fv
    }

    echo "Dependencies installed on Fedora/RHEL."
}

install_arch() {
    sudo pacman -Sy --noconfirm ffmpeg jq poppler fd ripgrep fzf zoxide imagemagick xclip p7zip unzip curl fontconfig || true
    # Nerd Fonts user install via GitHub or community repo
    fc-list | grep -qi nerd || {
        echo "Please install nerd-fonts manually from AUR or using a helper like paru/yay."
    }

    echo "Dependencies installed on Arch Linux."
}

install_opensuse() {
    sudo zypper install -y ffmpeg jq poppler-tools fd ripgrep fzf zoxide ImageMagick xclip p7zip unzip curl fontconfig || true

    if ! fc-list | grep -qi nerd; then
        echo "Installing Nerd Fonts on openSUSE via manual script..."
        curl -fsSL https://raw.githubusercontent.com/monoira/nefoin/main/install.sh | bash -s -- "FiraCode"
        fc-cache -fv
    fi

    echo "Dependencies installed on openSUSE."
}

# Clipboard support on Linux: check environment and install the best clipboard tool available
install_clipboard_linux() {
    if [[ "$(pgrep -x wayland)" ]]; then
        # Wayland detected, install wl-clipboard if available
        if [[ "$PM" == "apt-get" ]]; then
            sudo apt-get install -y wl-clipboard || true
        elif [[ "$PM" == "dnf" ]]; then
            sudo dnf install -y wl-clipboard || true
        elif [[ "$PM" == "pacman" ]]; then
            sudo pacman -Sy --noconfirm wl-clipboard || true
        elif [[ "$PM" == "zypper" ]]; then
            sudo zypper install -y wl-clipboard || true
        fi
    else
        # Not Wayland, install xclip or xsel
        if ! command -v xclip &>/dev/null; then
            if [[ "$PM" == "apt-get" ]]; then
                sudo apt-get install -y xclip || true
            elif [[ "$PM" == "dnf" ]]; then
                sudo dnf install -y xclip || true
            elif [[ "$PM" == "pacman" ]]; then
                sudo pacman -Sy --noconfirm xclip || true
            elif [[ "$PM" == "zypper" ]]; then
                sudo zypper install -y xclip || true
            fi
        fi
    fi
}

# Dispatch install by OS/distro
if [[ "$OS" == "Darwin" ]]; then
    install_mac
elif [[ "$OS" == "Linux" ]]; then
    case "$DISTRO" in
    ubuntu | debian) install_debian ;;
    fedora | centos | rhel) install_fedora ;;
    arch) install_arch ;;
    opensuse* | suse) install_opensuse ;;
    *)
        echo "Unsupported Linux distro: $DISTRO"
        exit 1
        ;;
    esac
    install_clipboard_linux
else
    echo "Unsupported OS: $OS"
    exit 1
fi

echo "All dependencies installed."
