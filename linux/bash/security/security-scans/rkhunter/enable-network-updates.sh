#!/usr/bin/env bash
set -euo pipefail
umask 077

usage() {
  cat << 'EOF'
Usage: enable-network-updates.sh [--dry-run]

Explicitly enable upstream rkhunter data downloads.

This changes:
  WEB_CMD=curl or WEB_CMD=wget
  UPDATE_MIRRORS=1
  MIRRORS_MODE=0

Requires the standard /etc/rkhunter.conf layout.
Does not update the trusted file-properties baseline.
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
      printf 'Unknown option: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

[[ "$(uname -s)" == Linux ]] || {
  printf 'Linux only.\n' >&2
  exit 2
}

[[ "$EUID" -eq 0 ]] || {
  printf 'Run with sudo.\n' >&2
  exit 2
}

CONFIG=/etc/rkhunter.conf

[[ -f "$CONFIG" && ! -L "$CONFIG" ]] || {
  printf 'Expected a regular, non-symlink configuration: %s\n' "$CONFIG" >&2
  exit 2
}

command -v rkhunter > /dev/null 2>&1 || {
  printf 'rkhunter is not installed.\n' >&2
  exit 2
}

## Require wget for this adapter rather than selecting curl, whose
#  rkhunter-generated command does not follow the observed redirects.
if command -v wget > /dev/null 2>&1; then
  DOWNLOADER=wget
else
  printf 'Install wget before enabling rkhunter network updates.\n' >&2
  exit 2
fi

SETTING_REGEX='^[[:space:]]*(WEB_CMD|UPDATE_MIRRORS|MIRRORS_MODE)='

for file in /etc/rkhunter.conf.local /etc/rkhunter.d/*.conf; do
  [[ -f "$file" ]] || continue

  if grep -Eq "$SETTING_REGEX" "$file"; then
    printf 'Conflicting local settings found in %s; review before proceeding.\n' \
      "$file" >&2
    exit 2
  fi
done

printf 'Configuration: %s\n' "$CONFIG"
printf 'Planned settings:\n'
printf '  WEB_CMD=%s\n' "$DOWNLOADER"
printf '  UPDATE_MIRRORS=1\n'
printf '  MIRRORS_MODE=0\n'

if [[ "$DRY_RUN" -eq 1 ]]; then
  exit 0
fi

BACKUP="$(mktemp "${CONFIG}.backup.XXXXXXXX")"
cp -p -- "$CONFIG" "$BACKUP"

TEMP="$(mktemp "${CONFIG}.tmp.XXXXXXXX")"
trap 'rm -f -- "$TEMP"' EXIT

awk '
  !/^[[:space:]]*(WEB_CMD|UPDATE_MIRRORS|MIRRORS_MODE)=/
' "$CONFIG" > "$TEMP"

{
  printf '\n# Explicitly enabled by security-scans setup.\n'
  printf 'WEB_CMD=%s\n' "$DOWNLOADER"
  printf 'UPDATE_MIRRORS=1\n'
  printf 'MIRRORS_MODE=0\n'
} >> "$TEMP"

## Preserve the existing file's ownership, mode, and security label.
cat "$TEMP" > "$CONFIG"

printf 'Backup: %s\n' "$BACKUP"

if ! rkhunter --config-check; then
  printf 'Configuration validation failed; restoring backup.\n' >&2
  cat "$BACKUP" > "$CONFIG"
  exit 2
fi

printf 'Network updates enabled. Trusted baseline was not changed.\n'
