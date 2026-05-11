#!/usr/bin/env bash
set -uo pipefail

if ! command -v curl &>/dev/null; then
  echo "[ERROR] curl is not installed."
  exit 1
fi

REPO="PrismLauncher/PrismLauncher"
API_URL="https://api.github.com/repos/${REPO}/releases/latest"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

OS="$(uname -s)"
ARCH="$(uname -m)"

if [[ "$OS" == "Linux" ]] && command -v flatpak >/dev/null 2>&1; then
  flatpak remote-add --if-not-exists flathub \
    https://dl.flathub.org/repo/flathub.flatpakrepo
  
  flatpak install -y flathub org.prismlauncher.PrismLauncher

  if [[ $? -ne 0 ]]; then
    echo "[ERROR] Failed to install PrismLauncher via Flatpak."
    echo "Attempting regular install."
  else
    echo "PrismLauncher installed via Flatpak."
    exit
  fi
fi

case "$ARCH" in
  x86_64|amd64) ARCH="x86_64" ;;
  arm64|aarch64) ARCH="arm64" ;;
  *) exit 1 ;;
esac

RELEASE_JSON="$(curl -fsSL "$API_URL")"

echo "Getting latest release for $OS/$ARCH"

if [[ "$OS" == "Linux" ]]; then
  DOWNLOAD_URL="$(
    echo "$RELEASE_JSON" |
    grep -Eo '"browser_download_url":[^"]+' |
    cut -d'"' -f4 |
    grep 'PrismLauncher-Linux-Qt6-Portable-.*\.tar\.gz' |
    head -n1
  )"

  if [[ -z "$DOWNLOAD_URL" && "$ARCH" == "x86_64" ]]; then
    DOWNLOAD_URL="$(
      echo "$RELEASE_JSON" |
      grep -Eo '"browser_download_url":[^"]+' |
      cut -d'"' -f4 |
      grep 'PrismLauncher-Linux-x86_64\.AppImage$' |
      head -n1
    )"
  fi
elif [[ "$OS" == "Darwin" ]]; then
  DOWNLOAD_URL="$(
    echo "$RELEASE_JSON" |
    grep -Eo '"browser_download_url":[^"]+' |
    cut -d'"' -f4 |
    grep 'PrismLauncher-macOS-.*\.zip' |
    grep -v Legacy |
    head -n1
  )"
else
  exit 1
fi

[[ -n "$DOWNLOAD_URL" ]]

echo "Downloading release"
FILE="$TMPDIR/$(basename "$DOWNLOAD_URL")"
curl -fL "$DOWNLOAD_URL" -o "$FILE"

echo "Installing PrismLauncher"

## Linux
if [[ "$OS" == "Linux" ]]; then
  sudo mkdir -p /opt/prismlauncher
  sudo rm -rf /opt/prismlauncher/*

  if [[ "$FILE" == *.tar.gz ]]; then
    sudo tar -xzf "$FILE" -C /opt/prismlauncher --strip-components=1

    sudo chmod +x /opt/prismlauncher/prismlauncher

    sudo ln -sf /opt/prismlauncher/prismlauncher /usr/local/bin/prismlauncher
  else
    sudo cp "$FILE" /opt/prismlauncher/prismlauncher.AppImage

    sudo chmod +x /opt/prismlauncher/prismlauncher.AppImage

    sudo ln -sf /opt/prismlauncher/prismlauncher.AppImage /usr/local/bin/prismlauncher
  fi

  echo "PrismLauncher installed"
  exit 0

## macOS
else
  unzip -q "$FILE" -d "$TMPDIR/app"

  APP="$(find "$TMPDIR/app" -maxdepth 1 -name '*.app' | head -n1)"

  [[ -n "$APP" ]]

  mv "$APP" /Applications/
fi
