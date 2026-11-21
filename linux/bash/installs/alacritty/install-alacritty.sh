#!/usr/bin/env bash
set -Eeuo pipefail

## Install Alacritty using the native package manager.
#  https://github.com/alacritty/alacritty

log() {
  printf '\n==> %s\n' "$*"
}

errexit() {
  printf '\nERROR: %s\n' "$*" >&2
  exit 1
}

[[ "$(uname -s)" == "Linux" ]] ||
  errexit "This script is for Linux. Use the PowerShell script on Windows."

[[ -r /etc/os-release ]] ||
  errexit "Cannot determine Linux distribution."

# shellcheck disable=SC1091
source /etc/os-release

DISTRO="${ID,,}"
PRETTY="${PRETTY_NAME:-$DISTRO}"

log "Detected $PRETTY"

if [[ "$EUID" -eq 0 ]]; then
  SUDO=()
elif command -v sudo > /dev/null 2>&1; then
  SUDO=(sudo)
else
  errexit "Please install sudo or run this script as root."
fi

run() {
  "${SUDO[@]}" "$@"
}

case "$DISTRO" in

  arch | manjaro | endeavouros)
    log "Installing from Arch repositories"

    run pacman -Syu --needed --noconfirm alacritty
    ;;

  ubuntu | pop)
    log "Installing from the Alacritty PPA"

    run apt-get update

    if ! command -v add-apt-repository > /dev/null 2>&1; then
      run apt-get install -y software-properties-common
    fi

    if ! grep -Rq 'mmstick76/alacritty' \
      /etc/apt/sources.list.d/ 2> /dev/null; then
      run add-apt-repository -y ppa:mmstick76/alacritty
    fi

    run apt-get update
    run apt-get install -y alacritty
    ;;

  debian)
    log "Installing from Debian repositories"

    run apt-get update
    run apt-get install -y alacritty
    ;;

  fedora)
    log "Installing from Fedora COPR"

    if ! command -v dnf > /dev/null 2>&1; then
      errexit "dnf is unavailable."
    fi

    run dnf install -y alacritty
    ;;

  rhel | centos | rocky | almalinux | ol)
    log "Checking RHEL-family repositories"

    if ! dnf info alacritty > /dev/null 2>&1; then
      cat >&2 << EOF
Alacritty is not available in the currently enabled repositories.

I have deliberately not enabled a third-party repository automatically.

Options:
  - Enable a trusted repository providing Alacritty.
  - Install using Snap (Snapcrafters provides a package).
  - Consult https://github.com/alacritty/alacritty/releases

EOF
      exit 1
    fi

    run dnf install -y alacritty
    ;;

  opensuse-tumbleweed | opensuse)
    log "Installing from openSUSE repositories"

    run zypper refresh
    run zypper install -y alacritty
    ;;

  void)
    log "Installing from Void repositories"

    run xbps-install -Sy alacritty
    ;;

  gentoo)
    log "Installing from Gentoo repositories"

    run emerge --ask=n x11-terms/alacritty
    ;;

  solus)
    log "Installing from Solus repositories"

    run eopkg install -y alacritty
    ;;

  *)
    errexit "Unsupported distribution: $DISTRO"
    ;;
esac

log "Installation complete."

if command -v alacritty > /dev/null 2>&1; then
  alacritty --version
else
  log "Alacritty was installed, but is not currently in PATH."
fi
