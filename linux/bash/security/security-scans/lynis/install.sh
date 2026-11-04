#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

usage() {
  cat << 'EOF'
Usage: install.sh [options]

Options:
  --dry-run   Show installation commands without executing them
  -h, --help  Show help

Platforms:
  Linux: apt-get, dnf, yum, zypper, pacman, apk
  macOS: Homebrew

Behavior:
  - Skip installation if lynis is already on PATH
  - Install from enabled repositories
  - Verify that the lynis command is available
  - Do not run an audit or alter security settings
  - Do not install Homebrew or enable additional repositories

Run Homebrew installation as your normal user, not root.
Package availability depends on distribution release and repositories.
EOF
}

DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;

    -h | --help)
      usage
      exit 0
      ;;

    *)
      lynis_die "Unknown option: $1"
      ;;
  esac
done

lynis_require_platform
lynis_prepare_path

if lynis_have lynis; then
  lynis_log "Lynis is already available."
  lynis_log "Command: $(command -v lynis)"
  exit 0
fi

case "$(uname -s)" in
  Darwin)
    lynis_have brew ||
      lynis_die "Homebrew is required on macOS."

    [[ "$EUID" -ne 0 ]] ||
      lynis_die "Run Homebrew installation as your normal user."

    lynis_run brew install lynis
    ;;

  Linux)
    if lynis_have apt-get; then
      lynis_root apt-get update
      lynis_root apt-get install -y lynis

    elif lynis_have dnf; then
      lynis_root dnf install -y lynis

    elif lynis_have yum; then
      lynis_root yum install -y lynis

    elif lynis_have zypper; then
      lynis_root zypper --non-interactive install lynis

    elif lynis_have pacman; then
      lynis_root pacman -S --needed --noconfirm lynis

    elif lynis_have apk; then
      lynis_root apk add lynis

    else
      lynis_die "No supported Linux package manager found."
    fi
    ;;
esac

if [[ "$DRY_RUN" -eq 1 ]]; then
  lynis_log "Installation dry run complete."
  exit 0
fi

lynis_have lynis ||
  lynis_die "Installation completed, but lynis is not on PATH."

lynis_log "Installation complete."
lynis_log "Command: $(command -v lynis)"
lynis_log "Next: sudo ./scan.sh --verbose"
