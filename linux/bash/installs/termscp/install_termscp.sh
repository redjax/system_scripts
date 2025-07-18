#!/usr/bin/env bash

set -e

if ! command -v curl &>/dev/null; then
  echo "curl is not installed."
  exit 1
fi

## Detect OS
OS="$(uname -s)"
ARCH="$(uname -m)"

## Detect distro using /etc/os-release
if [ -f /etc/os-release ]; then
  . /etc/os-release
  DISTRO_ID=$ID
else
  echo "Cannot detect Linux distribution."
  exit 1
fi

## Get latest version from GitHub API
TERMSCP_VERSION=$(curl -s https://api.github.com/repos/veeso/termscp/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
## Remove leading 'v' if present (e.g., 'v${TERMSCP_VERSION}' -> '${TERMSCP_VERSION}')
TERMSCP_VERSION="${TERMSCP_VERSION#v}"


function install_sshpass {
  if ! command -v sshpass &>/dev/null; then
    read -rp "sshpass is not installed. Install it now? (y/n)" answer

    if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
      ## Choose package manager and install sshpass
      case "$DISTRO_ID" in
      ubuntu | debian)
        sudo apt update && sudo apt install -y sshpass
        ;;
      fedora)
        sudo dnf install -y sshpass
        ;;
      centos | rhel)
        sudo yum install -y sshpass
        ;;
      opensuse* | sles)
        sudo zypper install -y sshpass
        ;;
      arch)
        sudo pacman -Sy --noconfirm sshpass
        ;;
      *)
        echo "Unsupported or unknown distribution: $DISTRO_ID"
        exit 2
        ;;
      esac

      if ! command -v sshpass &>/dev/null; then
        echo "sshpass installation failed."
        exit 1
      else
        echo "sshpass installed successfully!"
      fi

    else
      echo "Skipping sshpass installation."
    fi
  fi
}

if command -v termscp &>/dev/null; then
  echo "termscp is already installed. Upgrade by running termscp --upgrade"
  install_sshpass
  if [[ $? -ne 0 ]]; then
    echo "Failed to install sshpass"
    exit 1
  fi

  exit 0
fi

echo "Installing termscp v${TERMSCP_VERSION}"

## Map to GitHub asset names
case "$OS" in
Linux)
  case "$ARCH" in
  x86_64)
    FILE="termscp-v${TERMSCP_VERSION}-x86_64-unknown-linux-gnu.tar.gz"
    ;;
  aarch64 | arm64)
    FILE="termscp-v${TERMSCP_VERSION}-aarch64-unknown-linux-gnu.tar.gz"
    ;;
  *)
    echo "Unsupported Linux architecture: $ARCH"
    exit 1
    ;;
  esac
  ;;
Darwin)
  case "$ARCH" in
  x86_64)
    FILE="termscp-v${TERMSCP_VERSION}-x86_64-apple-darwin.tar.gz"
    ;;
  arm64)
    FILE="termscp-v${TERMSCP_VERSION}-arm64-apple-darwin.tar.gz"
    ;;
  *)
    echo "Unsupported macOS architecture: $ARCH"
    exit 1
    ;;
  esac
  ;;
*)
  echo "Unsupported OS: $OS"
  exit 1
  ;;
esac

## Create a temporary directory
TMPDIR=$(mktemp -d)

## Download the release
URL="https://github.com/veeso/termscp/releases/download/v${TERMSCP_VERSION}/$FILE"
ARCHIVE="$TMPDIR/termscp.tar.gz"

## Download the archive to the temp directory
echo "Downloading $FILE from $URL"
curl -L -o "$ARCHIVE" "$URL"

## Extract the archive into the temp directory
tar -xzf "$ARCHIVE" -C "$TMPDIR"

if [ "$OS" = "Darwin" ]; then
  ## macOS: install to /usr/local/bin (may require sudo)
  install -m 755 "$TMPDIR/termscp" /usr/local/bin/
else
  ## Linux: install to /usr/local/bin (may require sudo)
  sudo install -m 755 "$TMPDIR/termscp" /usr/local/bin/
fi

echo "termscp installed successfully!"

exit 0
