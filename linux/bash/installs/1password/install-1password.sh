#!/bin/bash

set -e

## Detect OS and architecture
ARCH="$(uname -m)"
if [ -f /etc/os-release ]; then
  . /etc/os-release
  DISTRO_ID=$ID
else
  echo "Cannot detect Linux distribution."
  exit 1
fi

echo "Detected distro: $DISTRO_ID, architecture: $ARCH"

if ! command -v curl &>/dev/null; then
  echo "curl is not installed."
  exit 1
fi

install_debian_ubuntu() {
  echo "Installing 1Password on Debian/Ubuntu..."

  sudo mkdir -p /usr/share/keyrings
  curl -sS https://downloads.1password.com/linux/keys/1password.asc | sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg

  echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/amd64 stable main' | sudo tee /etc/apt/sources.list.d/1password.list

  sudo mkdir -p /etc/debsig/policies/AC2D62742012EA22/
  curl -sS https://downloads.1password.com/linux/debian/debsig/1password.pol | sudo tee /etc/debsig/policies/AC2D62742012EA22/1password.pol

  sudo mkdir -p /usr/share/debsig/keyrings/AC2D62742012EA22/
  curl -sS https://downloads.1password.com/linux/keys/1password.asc | sudo gpg --dearmor --output /usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg

  sudo apt update
  sudo apt install -y 1password
}

install_fedora_redhat() {
  echo "Installing 1Password on Fedora/Red Hat..."

  sudo rpm --import https://downloads.1password.com/linux/keys/1password.asc

  sudo tee /etc/yum.repos.d/1password.repo > /dev/null <<EOF
[1password]
name=1Password Stable Channel
baseurl=https://downloads.1password.com/linux/rpm/stable/\$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://downloads.1password.com/linux/keys/1password.asc
EOF

  if command -v dnf &> /dev/null; then
    sudo dnf install -y 1password
  else
    sudo yum install -y 1password
  fi
}

install_suse_opensuse() {
  echo "Installing 1Password on SUSE/openSUSE..."

  sudo rpm --import https://downloads.1password.com/linux/keys/1password.asc
  sudo zypper addrepo https://downloads.1password.com/linux/rpm/stable/x86_64 1password
  sudo zypper refresh
  sudo zypper install -y 1password
}

install_arch() {
  echo "Installing 1Password on Arch Linux..."

  ## Check if git and base-devel installed
  sudo pacman -Sy --noconfirm git base-devel gnupg

  ## Import key and build from AUR
  curl -sS https://downloads.1password.com/linux/keys/1password.asc | gpg --import

  ## Clone and build package
  TMPDIR=$(mktemp -d)
  git clone https://aur.archlinux.org/1password.git "$TMPDIR/1password"
  cd "$TMPDIR/1password" || exit
  makepkg -si --noconfirm
  cd - || exit
  rm -rf "$TMPDIR"
}

install_tarball() {
  echo "Installing 1Password from tarball for unsupported distro or ARM arch..."

  case "$ARCH" in
    x86_64|amd64)
      TARURL="https://downloads.1password.com/linux/tar/stable/x86_64/1password-latest.tar.gz"
      ;;
    aarch64|arm64)
      TARURL="https://downloads.1password.com/linux/tar/stable/aarch64/1password-latest.tar.gz"
      ;;
    *)
      echo "Unsupported architecture: $ARCH"
      exit 3
      ;;
  esac

  TMPDIR=$(mktemp -d)
  curl -sSO "$TARURL" -o "$TMPDIR/1password-latest.tar.gz"
  sudo mkdir -p /opt/1Password
  sudo tar -xf "$TMPDIR/1password-latest.tar.gz" -C /opt/1Password --strip-components=1
  sudo /opt/1Password/after-install.sh
  rm -rf "$TMPDIR"
}

case "$DISTRO_ID" in
  ubuntu|debian)
    install_debian_ubuntu
    ;;
  fedora|rhel|centos)
    install_fedora_redhat
    ;;
  opensuse*|sles)
    install_suse_opensuse
    ;;
  arch)
    install_arch
    ;;
  *)
    install_tarball
    ;;
esac

echo "1Password installation complete."
