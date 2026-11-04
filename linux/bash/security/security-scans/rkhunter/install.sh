#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

usage() {
  cat << 'EOF'
Usage: install.sh [options]

Options:
  --config FILE      Main configuration to validate after installation
  --output-dir DIR   Configuration-report parent directory
                     Default: /var/log/security-scans/rkhunter
  --verbose          Show full configuration-validation output
  --dry-run          Show planned actions without making changes
  -h, --help         Show help

Supported package managers:
  apt-get, dnf, yum, zypper, pacman, apk

Behavior:
  - Install rkhunter if missing
  - Validate the installed configuration
  - Do not enable additional repositories
  - Do not update detection data
  - Do not initialize or refresh the trusted baseline

Package availability depends on distribution version and repositories.
Package-manager installation hooks remain distribution-controlled.
EOF
}

DRY_RUN=0
CONFIG=
OUTPUT_DIR=/var/log/security-scans/rkhunter
VERBOSE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config | --output-dir)
      rkh_need_value "$@"

      case "$1" in
        --config) CONFIG="$2" ;;
        --output-dir) OUTPUT_DIR="$2" ;;
      esac

      shift 2
      ;;

    --verbose)
      VERBOSE=1
      shift
      ;;

    --dry-run)
      DRY_RUN=1
      shift
      ;;

    -h | --help)
      usage
      exit 0
      ;;

    *)
      rkh_die "Unknown option: $1"
      ;;
  esac
done

rkh_require_linux

PATH="$PATH:/usr/local/sbin:/usr/sbin:/sbin"
export PATH

[[ -f "$SCRIPT_DIR/configure.sh" ]] ||
  rkh_die "Missing configuration script: $SCRIPT_DIR/configure.sh"

OUTPUT_DIR="$(rkh_absolute_path "$OUTPUT_DIR")"

if [[ -n "$CONFIG" ]]; then
  CONFIG="$(rkh_absolute_path "$CONFIG")"

  [[ -f "$CONFIG" && -r "$CONFIG" ]] ||
    rkh_die "Configuration is missing or unreadable: $CONFIG"
fi

if rkh_have rkhunter; then
  rkh_log "rkhunter is already available."
else
  if rkh_have apt-get; then
    rkh_root apt-get update
    rkh_root apt-get install -y rkhunter

  elif rkh_have dnf; then
    rkh_root dnf install -y rkhunter

  elif rkh_have yum; then
    rkh_root yum install -y rkhunter

  elif rkh_have zypper; then
    rkh_root zypper --non-interactive install rkhunter

  elif rkh_have pacman; then
    rkh_root pacman -S --needed --noconfirm rkhunter

  elif rkh_have apk; then
    rkh_root apk add rkhunter

  else
    rkh_die "No supported package manager found."
  fi
fi

if [[ "$DRY_RUN" -eq 0 ]]; then
  rkh_have rkhunter ||
    rkh_die "Installation completed, but rkhunter is not on PATH."
fi

CONFIG_ARGS=(--output-dir "$OUTPUT_DIR")

if [[ -n "$CONFIG" ]]; then
  CONFIG_ARGS+=(--config "$CONFIG")
fi

if [[ "$VERBOSE" -eq 1 ]]; then
  CONFIG_ARGS+=(--verbose)
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  CONFIG_ARGS+=(--dry-run)

  # Execute the configuration wrapper's dry run without elevation.
  /bin/bash "$SCRIPT_DIR/configure.sh" "${CONFIG_ARGS[@]}"
elif [[ "$EUID" -eq 0 ]]; then
  /bin/bash "$SCRIPT_DIR/configure.sh" "${CONFIG_ARGS[@]}"
else
  rkh_have sudo ||
    rkh_die "Configuration validation requires root; sudo is unavailable."

  sudo -- /bin/bash "$SCRIPT_DIR/configure.sh" "${CONFIG_ARGS[@]}"
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  rkh_log "Installation dry run complete."
else
  rkh_log "Installation and configuration validation complete."
  rkh_log "Detection-data and baseline updates were not requested."
fi
