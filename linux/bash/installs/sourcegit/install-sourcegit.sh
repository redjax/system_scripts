#!/usr/bin/env bash
set -euo pipefail

## Source key & list for apt package manager
REPO_KEY="/etc/apt/keyrings/sourcegit.asc"
REPO_LIST="/etc/apt/sources.list.d/sourcegit.list"

## Check if required tool/command is available or exit
function need() {
  command -v "$1" > /dev/null || {
    echo "Missing required command: $1"
    exit 1
  }
}

need curl

## Get CPU arch
ARCH="$(uname -m)"

function confirm() {
  read -rp "$1 [y/N] " reply
  [[ "$reply" =~ ^[Yy]$ ]]
}

function install_appimage() {
  echo "Installing SourceGit AppImage"

  ## Get latest version number from github
  VERSION="$(curl -fsSL \
    https://api.github.com/repos/sourcegit-scm/sourcegit/releases/latest |
    sed -n 's/.*"tag_name": *"v\([^"]*\)".*/\1/p')"

  case "$ARCH" in
    x86_64)
      FILE="sourcegit_${VERSION}.linux-x64.AppImage"
      ;;
    aarch64 | arm64)
      FILE="sourcegit_${VERSION}.linux-arm64.AppImage"
      ;;
    *)
      echo "Unsupported architecture: $ARCH"
      exit 1
      ;;
  esac

  sudo mkdir -p /opt/sourcegit

  ## Download appimage
  curl -fL \
    -o /tmp/sourcegit.AppImage \
    "https://github.com/sourcegit-scm/sourcegit/releases/download/v${VERSION}/${FILE}"

  ## Install appimage
  sudo install -m755 /tmp/sourcegit.AppImage /opt/sourcegit/sourcegit

  cat << 'EOF' | sudo tee /usr/local/bin/sourcegit > /dev/null
#!/bin/sh
exec /opt/sourcegit/sourcegit "$@"
EOF

  ## Mark sourcegit executable
  sudo chmod +x /usr/local/bin/sourcegit
  rm -f /tmp/sourcegit.AppImage

  echo "Installed SourceGit AppImage"
}

function install_apt() {

  sudo mkdir -p /etc/apt/keyrings

  ## Add signing key or retrieve from remote
  if [[ ! -f "$REPO_KEY" ]]; then
    curl -fsSL \
      https://codeberg.org/api/packages/yataro/debian/repository.key |
      sudo tee "$REPO_KEY" > /dev/null
  fi

  ## Add repo list or retrieve from remote
  if [[ ! -f "$REPO_LIST" ]]; then
    echo "deb [signed-by=$REPO_KEY arch=$(dpkg --print-architecture)] https://codeberg.org/api/packages/yataro/debian generic main" |
      sudo tee "$REPO_LIST" > /dev/null
  fi

  sudo apt update
  sudo apt install -y sourcegit
}

function install_dnf() {

  ## Temporary directory for rpm package download
  TMP="$(mktemp)"

  ## Download rpm package
  curl -fsSL \
    https://codeberg.org/api/packages/yataro/rpm.repo |
    sed 's/gpgcheck=1/gpgcheck=0/' > "$TMP"

  ## Install dnf package
  if dnf config-manager --help 2>&1 | grep -q "addrepo"; then
    sudo dnf config-manager addrepo --from-repofile="$TMP"
  else
    sudo dnf config-manager --add-repo "$TMP"
  fi

  sudo dnf install -y sourcegit

  rm -f "$TMP"
}

## Already installed

if command -v sourcegit > /dev/null 2>&1 || [[ -x /opt/sourcegit/sourcegit ]]; then

  echo "SourceGit is already installed."

  ## Prompt to upgrade
  if ! confirm "Upgrade it?"; then
    exit 0
  fi

  ## Update with apt
  if command -v dpkg > /dev/null && dpkg -s sourcegit > /dev/null 2>&1; then
    sudo apt update
    sudo apt install --only-upgrade -y sourcegit

  ## Update with dnf
  elif command -v rpm > /dev/null && rpm -q sourcegit > /dev/null 2>&1; then
    sudo dnf upgrade -y sourcegit

  ## Update appimage
  elif [[ -x /opt/sourcegit/sourcegit ]]; then
    install_appimage

  else
    echo "Existing installation method could not be determined."
    exit 1
  fi

## Sourcegit not installed, do install
else

  if command -v apt > /dev/null; then
    install_apt

  elif command -v dnf > /dev/null; then
    install_dnf

  else
    echo "No supported package manager detected."
    install_appimage
  fi
fi

echo

## Credential helper check

gcm_installed=0
libsecret_installed=0

if command -v git-credential-manager > /dev/null 2>&1; then
  echo "git-credential-manager: installed"
  gcm_installed=1
else
  echo "[WARNING] git-credential-manager: not installed"
fi

if command -v git-credential-libsecret > /dev/null 2>&1; then
  echo "git-credential-libsecret: installed"
  libsecret_installed=1
else
  echo "[WARNING] git-credential-libsecret: not installed"
fi

if [[ $gcm_installed -eq 0 && $libsecret_installed -eq 0 ]]; then
  echo
  echo "WARNING:"
  echo "Neither git-credential-manager nor git-credential-libsecret is installed."
  echo "HTTPS authentication may not work correctly."
  echo

  if confirm "Would you like to install a supported Git credential helper?"; then

    if command -v apt > /dev/null 2>&1; then
      echo "Installing git-credential-manager"

      sudo apt update

      if sudo apt install -y git-credential-manager; then
        echo "git-credential-manager installed."
      else
        echo "git-credential-manager package not available."
        echo "Installing libsecret-tools instead"
        sudo apt install -y libsecret-tools
      fi

    else
      echo
      echo "[WARNING] Automatic installation of Git credential helpers is not supported on this distribution."
      echo "Please install either:"
      echo "  - git-credential-manager"
      echo "  - git-credential-libsecret"
    fi
  fi
fi

echo
echo "SourceGit installation complete."
