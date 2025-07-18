#!/usr/bin/env bash

# set -e

if ! command -v curl &>/dev/null; then
  echo "curl is not installed."
  exit 1
fi

OS="$(uname -s)"
ARCH="$(uname -m)"
# echo "OS: $OS, ARCH: $ARCH"

## Detect distro using /etc/os-release
if [ -f /etc/os-release ]; then
  . /etc/os-release
  DISTRO_ID=$ID
else
  echo "Cannot detect Linux distribution."
  exit 1
fi
echo "Detected distro: $DISTRO_ID"

## Get session manager, Wayland or X11.
#  Only needed for aarch64 devices
SESSION_MANAGER=$XDG_SESSION_TYPE
echo "Detected session manager: $SESSION_MANAGER"

if [[ "$SESSION_MANAGER" != "wayland" && "$SESSION_MANAGER" != "x11" ]]; then
  echo "Unsupported session manager: $SESSION_MANAGER"
  exit 1
fi

## Get latest version from GitHub API
RIO_VERSION=$(curl -s https://api.github.com/repos/raphamorim/rio/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
if [[ $? -ne 0 ]]; then
  echo "[ERROR] Could not fetch latest version."
  exit 1
fi

RIO_VERSION="${RIO_VERSION#v}"

echo "Installing Rio terminal v${RIO_VERSION}"

## Map to GitHub asset names
case "$OS" in
Linux)
  case "$ARCH" in
    x86_64)
      if [[ "$SESSION_MANAGER" == "wayland" ]]; then
        FILE="rioterm-${RIO_VERSION}-1.x86_64_wayland.rpm"
      elif [[ "$SESSION_MANAGER" == "x11" ]]; then
        FILE="rioterm-${RIO_VERSION}-1.x86_64_x11.rpm"
      else
        echo "Unsupported session manager: $SESSION_MANAGER"
        exit 1
      fi
      ;;
    aarch64|arm64)
      if [[ "$SESSION_MANAGER" == "wayland" ]]; then
        FILE="rioterm-${RIO_VERSION}-1.aarch64_wayland.rpm"
      elif [[ "$SESSION_MANAGER" == "x11" ]]; then
        FILE="rioterm-${RIO_VERSION}-1.aarch64_x11.rpm"
      else
        echo "Unsupported session manager: $SESSION_MANAGER"
        exit 1
      fi
      ;;
    *)
      echo "Unsupported Linux architecture: $ARCH"
      exit 1
      ;;
  esac
  ;;
Darwin)
  FILE=rio.dmg
  ;;
*)
  echo "Unsupported OS: $OS"
  exit 1
  ;;
esac

TMPDIR=$(mktemp -d)

## Download the release
URL="https://github.com/raphamorim/rio/releases/download/v${RIO_VERSION}/$FILE"
ARCHIVE="$TMPDIR/$FILE"

echo "Downloading $FILE from $URL"
curl -L -o "$ARCHIVE" "$URL"

## Install/extract
if [ "$OS" = "Darwin" ]; then
  echo "Extracting $ARCHIVE"
  unzip -o "$ARCHIVE" -d "$TMPDIR"

  ## Find the binary (assume it's named 'rio')
  BIN_PATH=$(find "$TMPDIR" -type f -name 'rio' | head -n 1)
  
  if [ -z "$BIN_PATH" ]; then
    echo "rio binary not found in archive."
    exit 1
  fi
  
  install -m 755 "$BIN_PATH" /usr/local/bin/
elif [ "$OS" = "Linux" ]; then
  if [[ "$FILE" == *.rpm ]]; then
    echo "Installing RPM package (requires sudo)"
    
    sudo rpm -i --replacepkgs "$ARCHIVE"
  elif [[ "$FILE" == *.AppImage ]]; then
    chmod +x "$ARCHIVE"
    
    sudo mv "$ARCHIVE" /usr/local/bin/rio
  else
    echo "Unknown Linux asset type: $FILE"
    
    exit 1
  fi
fi

if [[ $? -ne 0 ]]; then
  echo "[ERROR] Failed to install Rio."
  exit 1
else
    echo "Rio installed successfully!"
    exit 0
fi
