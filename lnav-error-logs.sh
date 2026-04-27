#!/usr/bin/env bash
set -euo pipefail

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

logs=()

add_if_exists() {
  for f in "$@"; do
    [[ -f "$f" ]] && logs+=("$f")
  done
}

journal_error_fallback() {
  if command -v journalctl >/dev/null 2>&1; then
    journalctl -b -p err --no-pager -o short-iso > "$tmpdir/journal-errors.log" || true
    [[ -s "$tmpdir/journal-errors.log" ]] && logs+=("$tmpdir/journal-errors.log")
  fi
}

. /etc/os-release 2>/dev/null || true

case "${ID:-}" in
  debian|ubuntu)
    add_if_exists /var/log/syslog /var/log/kern.log /var/log/auth.log
    ;;
  fedora|rhel|centos|rocky|almalinux|ol)
    add_if_exists /var/log/messages /var/log/secure /var/log/dnf.log /var/log/yum.log
    ;;
  arch|manjaro|endeavouros)
    add_if_exists /var/log/pacman.log
    ;;
  opensuse*|suse|sles)
    add_if_exists /var/log/messages /var/log/zypp/history
    ;;
esac

if ((${#logs[@]} == 0)); then
  journal_error_fallback
fi

if ((${#logs[@]} == 0)); then
  echo "No error logs found."
  exit 1
fi

sudo lnav "${logs[@]}"

