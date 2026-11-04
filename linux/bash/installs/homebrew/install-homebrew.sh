#!/usr/bin/env bash
set -euo pipefail

readonly DEFAULT_HOMEBREW_INSTALL_URL="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"

# Environment-variable defaults.
INSTALL_GCC="${INSTALL_GCC:-0}"
NONINTERACTIVE="${NONINTERACTIVE:-1}"
HOMEBREW_INSTALL_URL="${HOMEBREW_INSTALL_URL:-$DEFAULT_HOMEBREW_INSTALL_URL}"

log() {
  printf '[homebrew] %s\n' "$*"
}

errexit() {
  printf '[homebrew] ERROR: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<EOF
Usage:
  $(basename "$0") [OPTIONS]

Install and configure Homebrew for the current script process. Installation options can be configured
via environment variable or --options.

Options:
  -h, --help             Show this help menu and exit
  --install-gcc          Install Homebrew GCC after Homebrew is available. Overrides INSTALL_GCC.
  --no-install-gcc       Do not install Homebrew GCC. Overrides INSTALL_GCC.
  -i, --interactive      Run the Homebrew installer interactively. Overrides NONINTERACTIVE.
  -y, --non-interactive  Run the Homebrew installer with NONINTERACTIVE=1. Overrides NONINTERACTIVE.
  --install-url          URL Use URL as the Homebrew installer URL. Overrides HOMEBREW_INSTALL_URL.
  --                     Stop parsing options.

Environment variables:
  INSTALL_GCC=0|1
      Install GCC after Homebrew installation.
      Default: 0

  NONINTERACTIVE=0|1
      Whether to run the Homebrew installer non-interactively.
      Default: 1

  HOMEBREW_INSTALL_URL=URL
      URL for the Homebrew installation script.
      Default: $DEFAULT_HOMEBREW_INSTALL_URL

Examples:
  $(basename "$0")
  $(basename "$0") --install-gcc
  $(basename "$0") --interactive
  INSTALL_GCC=1 $(basename "$0")
  NONINTERACTIVE=0 $(basename "$0")
  $(basename "$0") --install-url https://example.invalid/install.sh
EOF
}

require_boolean() {
  local name="$1"
  local value="$2"

  case "$value" in
    0 | 1) ;;
    *)
      errexit "$name must be 0 or 1; got: $value"
      ;;
  esac
}

require_option_value() {
  local option="$1"

  if [[ $# -lt 2 || -z "${2:-}" ]]; then
    errexit "$option requires a value."
  fi
}

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    --install-gcc)
      INSTALL_GCC=1
      shift
      ;;
    --no-install-gcc)
      INSTALL_GCC=0
      shift
      ;;
    -i | --interactive)
      NONINTERACTIVE=0
      shift
      ;;
    -y | --non-interactive)
      NONINTERACTIVE=1
      shift
      ;;
    --install-url)
      require_option_value "$1" "$@"
      HOMEBREW_INSTALL_URL="$2"
      shift 2
      ;;
    --install-url=*)
      HOMEBREW_INSTALL_URL="${1#*=}"

      if [[ -z "$HOMEBREW_INSTALL_URL" ]]; then
        errexit "--install-url requires a non-empty value."
      fi

      shift
      ;;
    --)
      shift

      if [[ $# -gt 0 ]]; then
        errexit "Unexpected positional arguments: $*"
      fi

      break
      ;;
    -*)
      errexit "Unknown option: $1. Run $(basename "$0") --help for usage."
      ;;
    *)
      errexit "Unexpected positional argument: $1. Run $(basename "$0") --help for usage."
      ;;
  esac
done

require_boolean "INSTALL_GCC" "$INSTALL_GCC"
require_boolean "NONINTERACTIVE" "$NONINTERACTIVE"

## Detect OS
OS="$(uname -s)"

case "$OS" in
  Darwin)
    log "Detected macOS"
    ;;
  Linux)
    log "Detected Linux"
    ;;
  *)
    errexit "Unsupported operating system: $OS"
    ;;
esac

## Prerequisites
command -v curl >/dev/null 2>&1 ||
  errexit "curl is required but was not found."

find_brew() {
  if command -v brew >/dev/null 2>&1; then
    command -v brew
    return 0
  fi

  case "$OS" in
    Darwin)
      for path in \
        /opt/homebrew/bin/brew \
        /usr/local/bin/brew; do
        if [[ -x "$path" ]]; then
          printf '%s\n' "$path"
          return 0
        fi
      done
      ;;
    Linux)
      if [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
        printf '%s\n' /home/linuxbrew/.linuxbrew/bin/brew
        return 0
      fi
      ;;
  esac

  return 1
}

## Install Homebrew
if BREW="$(find_brew)"; then
  log "Homebrew already installed: $BREW"
else
  log "Installing Homebrew"
  log "Installer URL: $HOMEBREW_INSTALL_URL"

  if [[ "$NONINTERACTIVE" == "1" ]]; then
    log "Installer mode: non-interactive"

    NONINTERACTIVE=1 /bin/bash -c \
      "$(curl -fsSL "$HOMEBREW_INSTALL_URL")"
  else
    log "Installer mode: interactive"

    /bin/bash -c \
      "$(curl -fsSL "$HOMEBREW_INSTALL_URL")"
  fi

  BREW="$(find_brew)" ||
    errexit "Homebrew installation completed, but brew could not be found."

  log "Homebrew installed: $BREW"
fi

## Configure Homebrew for this script process only.
#  This changes PATH, MANPATH, INFOPATH, HOMEBREW_PREFIX, etc. only while this script runs.
eval "$("$BREW" shellenv)"

log "Homebrew prefix: $(brew --prefix)"
log "Homebrew version: $(brew --version | head -n 1)"

if [[ "$INSTALL_GCC" == "1" ]]; then
  if brew list --versions gcc >/dev/null 2>&1; then
    log "GCC already installed."
  else
    log "Installing GCC"
    brew install gcc
  fi
fi

log "Homebrew setup complete."
