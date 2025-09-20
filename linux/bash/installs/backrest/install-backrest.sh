#!/usr/bin/env bash
set -uo pipefail

if ! command -v curl &>/dev/null; then
    echo "curl is not installed."
    exit 1
fi

## Default values
BIND_ADDRESS="127.0.0.1"
PORT="9898"
ALLOW_REMOTE="false"

REPO="garethgeorge/backrest"
TMPDIR="$(mktemp -d)"
## Create systemd service with user-set bind address and port
SERVICE_PATH="/etc/systemd/system/backrest.service"

# Cleanup temp directory on exit
cleanup() {
    if [ -n "${TMPDIR:-}" ] && [ -d "$TMPDIR" ]; then
        rm -rf -- "$TMPDIR"
    fi
}
trap cleanup EXIT

# Validate IP or hostname loosely (allow localhost or IPs)
validate_host() {
    local host=$1
    if [[ ! "$host" =~ ^([a-zA-Z0-9.-]+|localhost|0\.0\.0\.0)$ ]]; then
        echo "Invalid bind address: $host"
        exit 1
    fi
}

# Validate port number range 1-65535
validate_port() {
    local port=$1
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        echo "Invalid port number: $port"
        exit 1
    fi
}

# Parse CLI args
while [[ $# -gt 0 ]]; do
  case $1 in
    -b|--bind-address)
      if [ -z "${2:-}" ]; then
        echo "ERROR: --bind-address requires an argument."
        exit 1
      fi
      validate_host "$2"
      BIND_ADDRESS="$2"
      shift 2
      ;;
    -p|--port)
      if [ -z "${2:-}" ]; then
        echo "ERROR: --port requires an argument."
        exit 1
      fi
      validate_port "$2"
      PORT="$2"
      shift 2
      ;;
    --allow-remote)
      ALLOW_REMOTE="true"
      shift
      ;;
    *)
      echo "Unknown parameter passed: $1"
      exit 1
      ;;
  esac
done

BACKREST_PORT="${BIND_ADDRESS}:${PORT}"

cd "$TMPDIR"

# Get latest release tag name
TAG=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

# Detect OS and ARCH
OS="$(uname -s)"
ARCH="$(uname -m)"

case "$OS" in
    Linux)   os="Linux" ;;
    Darwin)  os="Darwin" ;;
    *)       echo "Unsupported OS: $OS"; exit 1 ;;
esac

case "$ARCH" in
    x86_64)  arch="x86_64" ;;
    arm64|aarch64) arch="arm64" ;;
    armv6l)  arch="armv6" ;;
    *)       echo "Unsupported ARCH: $ARCH"; exit 1 ;;
esac

ASSET="backrest_${os}_${arch}.tar.gz"
URL="https://github.com/$REPO/releases/download/${TAG}/${ASSET}"

echo "Downloading $URL..."
curl -fsSL -o "$ASSET" "$URL"
tar -xzf "$ASSET"

# Run install script or copy binary with environment var setting
echo "Installing Backrest to /usr/local/bin with bind address $BACKREST_PORT ..."
if [ -f install.sh ]; then
    chmod +x install.sh
    if [ "$ALLOW_REMOTE" = "true" ]; then
        sudo BACKREST_PORT="$BACKREST_PORT" ./install.sh --allow-remote-access
    else
        sudo BACKREST_PORT="$BACKREST_PORT" ./install.sh
    fi
else
    sudo BACKREST_PORT="$BACKREST_PORT" install -m755 backrest /usr/local/bin/
fi

echo""
echo "Backrest installed successfully with bind address $BACKREST_PORT"
echo "Start/stop with sudo systemctl [start|stop] backrest"
