#!/usr/bin/env bash

set -euo pipefail

cleanup() {
  [[ -n "${TMPDIR:-}" && -d "$TMPDIR" ]] && rm -rf "$TMPDIR"
}
trap cleanup EXIT

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is not installed." >&2
  exit 1
fi

OS="$(uname -s)"
ARCH="$(uname -m)"

if [[ -f /etc/os-release ]]; then
  . /etc/os-release
  DISTRO_ID="${ID:-unknown}"
else
  echo "Cannot detect Linux distribution." >&2
  exit 1
fi

echo "Fetching latest termscp version" >&2

VERSION_JSON=$(curl -s https://api.github.com/repos/veeso/termscp/releases/latest)
if [[ -z "$VERSION_JSON" ]]; then
  echo "Failed to fetch GitHub API." >&2
  exit 1
fi

# Robust version extraction - multiple fallback methods
if [[ "$VERSION_JSON" =~ \"tag_name\":\ \"v([0-9]+\.[0-9]+\.[0-9]+)\" ]]; then
  TERMSCP_VERSION="${BASH_REMATCH[1]}"
elif echo "$VERSION_JSON" | grep -q '"tag_name"'; then
  TERMSCP_VERSION=$(echo "$VERSION_JSON" | grep -o '"tag_name": *"[^"]*"' | head -1 | cut -d'"' -f4 | sed 's/^v//')
else
  echo "Failed to parse version. Raw response:" >&2
  echo "$VERSION_JSON" | head -c 200 >&2
  exit 1
fi

echo "Found latest version: v$TERMSCP_VERSION" >&2

install_sshpass() {
  if ! command -v sshpass >/dev/null 2>&1; then
    echo "sshpass is not installed." >&2
    read -r -p "Install it now? (y/n): " answer
    echo ""
    
    [[ "$answer" =~ ^[Yy]$ ]] || { echo "sshpass skipped." >&2; return 0; }
    
    echo "Installing sshpass for $DISTRO_ID" >&2
    case "$DISTRO_ID" in
      ubuntu|debian) sudo dnf install -y sshpass ;;
      fedora) sudo dnf install -y sshpass ;;
      centos|rhel) sudo yum install -y sshpass ;;
      opensuse*|sles) sudo zypper install -y sshpass ;;
      arch) sudo pacman -Sy --noconfirm sshpass ;;
      *) echo "Unsupported distro: $DISTRO_ID" >&2; return 2 ;;
    esac
    
    command -v sshpass >/dev/null 2>&1 && echo "sshpass OK!" >&2 || {
      echo "sshpass install failed." >&2; return 1
    }
  fi
  return 0
}

if command -v termscp >/dev/null 2>&1; then
  CURRENT_VERSION=$(termscp --version 2>&1 | cut -d' ' -f2 || echo "unknown")
  echo "termscp v$CURRENT_VERSION already installed." >&2
  read -r -p "Upgrade to v$TERMSCP_VERSION? (y/n): " answer
  echo ""
  
  [[ "$answer" =~ ^[Yy]$ ]] || {
    echo "Upgrade skipped." >&2
    install_sshpass
    exit 0
  }
  echo "Upgrading" >&2
else
  echo "Installing termscp v$TERMSCP_VERSION" >&2
fi

# Architecture mapping
case "$OS" in
  Linux)
    [[ "$ARCH" = x86_64 ]] && FILE="termscp-v${TERMSCP_VERSION}-x86_64-unknown-linux-gnu.tar.gz" || \
    { [[ "$ARCH" = aarch64 || "$ARCH" = arm64 ]] && FILE="termscp-v${TERMSCP_VERSION}-aarch64-unknown-linux-gnu.tar.gz" || { echo "Bad arch: $ARCH" >&2; exit 1; }; }
    ;;
  Darwin)
    [[ "$ARCH" = x86_64 ]] && FILE="termscp-v${TERMSCP_VERSION}-x86_64-apple-darwin.tar.gz" || \
    { [[ "$ARCH" = arm64 ]] && FILE="termscp-v${TERMSCP_VERSION}-arm64-apple-darwin.tar.gz" || { echo "Bad macOS arch: $ARCH" >&2; exit 1; }; }
    ;;
  *) echo "Unsupported OS: $OS" >&2; exit 1 ;;
esac

TMPDIR=$(mktemp -d)
URL="https://github.com/veeso/termscp/releases/download/v${TERMSCP_VERSION}/$FILE"
ARCHIVE="$TMPDIR/termscp.tar.gz"

echo "Downloading $FILE" >&2
curl -L -f -o "$ARCHIVE" "$URL" || { echo "Download failed." >&2; exit 1; }

echo "Extracting" >&2
tar -xzf "$ARCHIVE" -C "$TMPDIR" || { echo "Extract failed." >&2; exit 1; }

[[ -f "$TMPDIR/termscp" ]] || { echo "No binary found." >&2; ls -la "$TMPDIR" >&2; exit 1; }

echo "Installing" >&2
if [[ "$OS" = Darwin ]]; then
  install -m 755 "$TMPDIR/termscp" /usr/local/bin/ 2>/dev/null || sudo install -m 755 "$TMPDIR/termscp" /usr/local/bin/
else
  sudo install -m 755 "$TMPDIR/termscp" /usr/local/bin/
fi

echo "termscp v$TERMSCP_VERSION installed!" >&2
install_sshpass

exit 0
