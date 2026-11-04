#!/usr/bin/env bash
set -euo pipefail

readonly LOG_TAG='homebrew-maintenance'
readonly BREW_BIN="${BREW_BIN:-/home/linuxbrew/.linuxbrew/bin/brew}"

log() {
  printf '[%s] %s\n' "$LOG_TAG" "$*"
}

if [[ ! -x "$BREW_BIN" ]]; then
  printf '[%s] ERROR: brew not found or not executable: %s\n' \
    "$LOG_TAG" "$BREW_BIN" >&2
  exit 1
fi

eval "$("$BREW_BIN" shellenv)"

log "Updating Homebrew and formula/cask metadata"
brew update

log "Installed outdated packages:"
brew outdated || true

if [[ "${HOMEBREW_AUTO_UPGRADE:-0}" == '1' ]]; then
  log "Upgrading formulae and normal casks"
  brew upgrade

  log "Removing old downloads and obsolete versions"
  brew cleanup
else
  log "Auto-upgrade disabled; set HOMEBREW_AUTO_UPGRADE=1 to enable it"
fi
