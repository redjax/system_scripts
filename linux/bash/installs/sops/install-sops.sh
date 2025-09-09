#!/usr/bin/env bash
set -e

TEMP_FILE=""
FORCE_INSTALL=""

cleanup() {
  if [[ -n "$TEMP_FILE" && -f "$TEMP_FILE" ]]; then
    echo "Cleaning up partial download..."
    rm -f "$TEMP_FILE"
  fi
}
trap cleanup EXIT

lowercase() {
  echo "$1" | tr '[:upper:]' '[:lower:]'
}

get_latest_release() {
  curl --silent "https://api.github.com/repos/getsops/sops/releases/latest" | 
    grep '"tag_name":' | 
    sed -E 's/.*"([^"]+)".*/\1/'
}

install_sops() {
  OS=$(lowercase "$(uname -s)")
  ARCH=$(uname -m)
  LATEST_RELEASE=$(get_latest_release)

  if [[ "$ARCH" == "x86_64" ]]; then
    ARCH="amd64"
  elif [[ "$ARCH" == "arm64" || "$ARCH" == "aarch64" ]]; then
    ARCH="arm64"
  else
    echo "Unsupported architecture: $ARCH"
    exit 1
  fi

  case "$OS" in
    linux)
      FILENAME="sops-${LATEST_RELEASE}.linux.${ARCH}"
      ;;
    darwin)
      FILENAME="sops-${LATEST_RELEASE}.darwin"
      ;;
    *)
      echo "Unsupported OS: $OS"
      exit 1
      ;;
  esac

  URL="https://github.com/getsops/sops/releases/download/${LATEST_RELEASE}/${FILENAME}"

  echo "Latest release is $LATEST_RELEASE"
  echo "Downloading $URL"
  TEMP_FILE="$FILENAME"
  if ! curl -fLo "$TEMP_FILE" "$URL"; then
    echo "Failed to download $URL"
    exit 1
  fi

  sudo mv "$TEMP_FILE" /usr/local/bin/sops
  sudo chmod +x /usr/local/bin/sops

  # Disable cleanup trap since file is moved/installed
  TEMP_FILE=""
  trap - EXIT

  echo "sops version $(sops --version) installed successfully."
}

if ! command -v curl &>/dev/null; then
    echo "[ERROR] curl is not installed."
    exit 1
fi

## Parse argss
while [[ $# -gt 0 ]]; do
  case $1 in
    -f|--force)
      FORCE_INSTALL="true"
      shift
      ;;
    *)
      echo "[ERROR] Invalid argument: $1"
      exit 1
      ;;
  esac
done

if [[ ! -z $FORCE_INSTALL ]] && [[ ! "$FORCE_INSTALL" == "" ]]; then
    install_sops
elif ! command -v sops --help &>/dev/null; then
    install_sops
else
    echo "sops is already installed."
  
    while true; do
        read -p "Force a reinstall? If a newer version is available, it will be installed (y/n): " reinstall_choice

        case $reinstall_choice in
            [Yy]* ) install_sops; break ;;
            [Nn]* ) echo "Skipping SOPS install."; exit ;;
            *) echo "Please answer y/n";;
        esac
    done
fi

if [[ $? -ne 0 ]]; then
    echo "[ERROR] Failed to install SOPS"
    exit $?
else
    echo "SOPS installed"
    exit 0
fi

