#!/usr/bin/env bash
set -u

if ! command -v lnav >&/dev/null; then
  echo "[ERROR] lnav is not installed" >&2
  exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

outfile="$tmpdir/security.log"
: > "$outfile"

append_file() {
  local f="$1"
  [[ -f "$f" ]] && cat "$f" >> "$outfile"
}

append_journal() {
  local pattern="$1"
  if command -v journalctl >/dev/null 2>&1; then
    journalctl -b --no-pager -o short-iso | grep -Ei "$pattern" >> "$outfile" || true
  fi
}

os_id=""
if [[ -r /etc/os-release ]]; then
  . /etc/os-release
  os_id="${ID:-}"
fi

case "$os_id" in
  debian|ubuntu)
    append_file /var/log/auth.log
    append_file /var/log/ufw.log
    append_file /var/log/audit/audit.log
    if [[ ! -s "$outfile" ]]; then
      append_journal 'ssh|sudo|pam|auth|ufw|audit|fail|denied|invalid user'
    fi
    ;;
  fedora|rhel|centos|rocky|almalinux|ol)
    append_file /var/log/secure
    append_file /var/log/audit/audit.log
    if [[ ! -s "$outfile" ]]; then
      append_journal 'ssh|sudo|pam|auth|audit|fail|denied|invalid user'
    fi
    ;;
  arch|manjaro|endeavouros)
    append_file /var/log/auth.log
    append_file /var/log/audit/audit.log
    if [[ ! -s "$outfile" ]]; then
      append_journal 'ssh|sudo|pam|auth|audit|fail|denied|invalid user'
    fi
    ;;
  opensuse*|suse|sles)
    append_file /var/log/messages
    append_file /var/log/audit/audit.log
    if [[ ! -s "$outfile" ]]; then
      append_journal 'ssh|sudo|pam|auth|audit|fail|denied|invalid user|zypper|rpm'
    fi
    ;;
  *)
    append_journal 'ssh|sudo|pam|auth|audit|fail|denied|invalid user'
    ;;
esac

if [[ ! -s "$outfile" ]]; then
  echo "No security logs found."
  exit 1
fi

lnav "$outfile"

