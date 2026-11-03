#!/bin/bash
set -e

REPO="GitFiend/Support"

# Check for required commands
for cmd in curl grep awk sed; do
  if ! command -v $cmd &>/dev/null; then
    echo "$cmd is required but not installed."
    exit 1
  fi
done

# Detect OS family
if [ -f /etc/os-release ]; then
  . /etc/os-release
  DISTRO_ID=${ID,,}
  DISTRO_LIKE=${ID_LIKE,,}
else
  echo "Cannot detect Linux distribution."
  exit 1
fi

if [[ "$DISTRO_ID" == "debian" || "$DISTRO_LIKE" == *"debian"* || "$DISTRO_ID" == "ubuntu" ]]; then
  PKG_TYPE="deb"
  INSTALL_CMD="sudo dpkg -i"
elif [[ "$DISTRO_ID" == "fedora" || "$DISTRO_ID" == "rhel" || "$DISTRO_ID" == "centos" || "$DISTRO_LIKE" == *"rhel"* || "$DISTRO_LIKE" == *"fedora"* ]]; then
  PKG_TYPE="rpm"
  INSTALL_CMD="sudo rpm -i"
else
  PKG_TYPE="AppImage"
  INSTALL_CMD="chmod +x"
fi

# Get latest release info from GitHub API
RELEASE_JSON=$(curl -s "https://api.github.com/repos/$REPO/releases/latest")

# Get tag name (for reference)
TAG_NAME=$(echo "$RELEASE_JSON" | grep -Po '"tag_name": *"\K[^"]+')

# Find the correct asset download URL
if [[ "$PKG_TYPE" == "deb" ]]; then
  ASSET_URL=$(echo "$RELEASE_JSON" | grep -Po '"browser_download_url": *"\K[^"]+\.deb')
elif [[ "$PKG_TYPE" == "rpm" ]]; then
  ASSET_URL=$(echo "$RELEASE_JSON" | grep -Po '"browser_download_url": *"\K[^"]+\.rpm')
else
  ASSET_URL=$(echo "$RELEASE_JSON" | grep -Po '"browser_download_url": *"\K[^"]+\.AppImage')
fi

if [ -z "$ASSET_URL" ]; then
  echo "Could not find a $PKG_TYPE asset in the latest release."
  exit 1
fi

ASSET_FILE=$(basename "$ASSET_URL")

# Use a temp directory
TMPDIR=$(mktemp -d)
cd "$TMPDIR"

if [ ! -f "$ASSET_FILE" ]; then
  echo "Downloading $ASSET_FILE..."
  curl -L -o "$ASSET_FILE" "$ASSET_URL"
else
  echo "$ASSET_FILE already exists in $TMPDIR, skipping download."
fi

echo "Installing $ASSET_FILE..."

INSTALL_SUCCCESS=1

if [[ "$PKG_TYPE" == "deb" || "$PKG_TYPE" == "rpm" ]]; then
  _INSTALL=$($INSTALL_CMD "$ASSET_FILE")
  INSTALL_SUCCESS=$?
elif [[ "$PKG_TYPE" == "AppImage" ]]; then
  chmod +x "$ASSET_FILE"
  # Optionally move to /usr/local/bin or prompt user
  sudo mv "$ASSET_FILE" /usr/local/bin/gitfiend.AppImage
  echo "GitFiend AppImage installed as /usr/local/bin/gitfiend.AppImage"

  INSTALL_SUCCESS=0
fi

if [[ $INSTALL_SUCCESS -ne 0 ]]; then
  echo "Failed to install $ASSET_FILE."
  exit 1
else
  echo "GitFiend installation complete."
  exit 0
fi
