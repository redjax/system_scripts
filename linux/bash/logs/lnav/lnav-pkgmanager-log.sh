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

journal_fallback() {
  local pattern="$1"
  if command -v journalctl >/dev/null 2>&1; then
    journalctl -b --no-pager -o short-iso | grep -Ei "$pattern" > "$tmpdir/journal.log" || true
    [[ -s "$tmpdir/journal.log" ]] && logs+=("$tmpdir/journal.log")
  fi
}

if [[ -r /etc/os-release ]]; then
  . /etc/os-release
  case "${ID:-}" in
    debian|ubuntu)
      add_if_exists /var/log/apt/history.log /var/log/dpkg.log
      ;;
    fedora|rhel|centos|rocky|almalinux|ol)
      add_if_exists /var/log/dnf.log /var/log/yum.log
      ;;
    arch|manjaro|endeavouros)
      add_if_exists /var/log/pacman.log
      ;;
    opensuse*|suse|sles)
      add_if_exists /var/log/zypp/history
      ;;
    *)
      ;;
  esac
fi

if ((${#logs[@]} == 0)); then
  case "${ID:-}" in
    debian|ubuntu)
      journal_fallback 'apt|dpkg|unattended-upgrades'
      ;;
    fedora|rhel|centos|rocky|almalinux|ol)
      journal_fallback 'dnf|yum|rpm'
      ;;
    arch|manjaro|endeavouros)
      journal_fallback 'pacman|libalpm'
      ;;
    opensuse*|suse|sles)
      journal_fallback 'zypper|zypp|rpm'
      ;;
  esac
fi

if ((${#logs[@]} == 0)); then
  echo "No package manager logs found."
  exit 1
fi

echo "Watching package manager logs"
echo "[WARNING] package manager logs require sudo"

sudo lnav "${logs[@]}"

