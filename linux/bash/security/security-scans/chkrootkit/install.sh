#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

usage() {
  cat <<'EOF'
Usage: install.sh [options]

Options:
  --dry-run   Show installation commands without executing them
  -h, --help  Show help

Supported package-manager paths:
  apt-get, dnf, yum, zypper, pacman, apk

Behavior:
  - Install chkrootkit if missing
  - Verify that its command is available

Package availability depends on distribution release and repositories.
An unavailable package produces an error.

On Arch, this script does not automatically build AUR packages.
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
    chk_die "Unknown option: $1"
    ;;
  esac
done

chk_require_linux
chk_prepare_path

if chk_have chkrootkit; then
  chk_log "chkrootkit is already available."
  chk_log "Command: $(command -v chkrootkit)"
  exit 0
fi

if chk_have apt-get; then
  chk_root apt-get update
  chk_root apt-get install -y chkrootkit

elif chk_have dnf; then
  chk_root dnf install -y chkrootkit

elif chk_have yum; then
  chk_root yum install -y chkrootkit

elif chk_have zypper; then
  chk_root zypper --non-interactive install chkrootkit

elif chk_have pacman; then
  chk_root pacman -S --needed --noconfirm chkrootkit

elif chk_have apk; then
  chk_root apk add chkrootkit

else
  chk_die "No supported package manager found."
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  chk_log "Installation dry run complete."
  exit 0
fi

chk_have chkrootkit ||
  chk_die "Installation completed, but chkrootkit is not on PATH."

chk_log "Installation complete."
chk_log "Command: $(command -v chkrootkit)"
chk_log "Next: sudo ./scan.sh --verbose"
