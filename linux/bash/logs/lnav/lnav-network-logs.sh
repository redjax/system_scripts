#!/usr/bin/env bash
set -euo pipefail

if ! command -v lnav >&/dev/null; then
  echo "[ERROR] lnav is not installed" >&2
  exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

logs=()

add_if_exists() {
  for f in "$@"; do
    [[ -f "$f" ]] && logs+=("$f")
  done
}

journal_network_fallback() {
  local pattern="$1"
  if command -v journalctl >/dev/null 2>&1; then
    journalctl -b --no-pager -o short-iso | grep -Ei "$pattern" > "$tmpdir/journal-network.log" || true
    [[ -s "$tmpdir/journal-network.log" ]] && logs+=("$tmpdir/journal-network.log")
  fi
}

. /etc/os-release 2>/dev/null || true

case "${ID:-}" in
  debian|ubuntu)
    add_if_exists /var/log/auth.log /var/log/ufw.log /var/log/kern.log /var/log/syslog
    ;;
  fedora|rhel|centos|rocky|almalinux|ol)
    add_if_exists /var/log/secure /var/log/messages /var/log/firewalld /var/log/audit/audit.log
    ;;
  arch|manjaro|endeavouros)
    add_if_exists /var/log/pacman.log
    ;;
  opensuse*|suse|sles)
    add_if_exists /var/log/messages /var/log/zypp/history
    ;;
esac

if ((${#logs[@]} == 0)); then
  case "${ID:-}" in
    debian|ubuntu) journal_network_fallback 'ssh|sshd|login|failed password|invalid user|ufw|conn|port|firewall|drop|deny' ;;
    fedora|rhel|centos|rocky|almalinux|ol) journal_network_fallback 'ssh|sshd|login|failed password|invalid user|firewalld|conn|port|drop|deny' ;;
    arch|manjaro|endeavouros) journal_network_fallback 'ssh|sshd|login|failed password|invalid user|conn|port|drop|deny' ;;
    opensuse*|suse|sles) journal_network_fallback 'ssh|sshd|login|failed password|invalid user|conn|port|drop|deny|zypper' ;;
  esac
fi

if ((${#logs[@]} == 0)); then
  echo "No network logs found."
  exit 1
fi

sudo lnav "${logs[@]}"

