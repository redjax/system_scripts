#!/usr/bin/env bash
set -euo pipefail

if ! command -v timedatectl >&/dev/null; then
  echo "[ERROR] timedatctl is not installed" >&2
  exit 1
fi

TZ="Etc/UTC"
LIST_TZ="false"

function usage() {
  cat <<EOF
Usage: ${0} [OPTIONS]

Options:
  -h, --help     Print this help menu
  -t, --timezone The timezone to set, i.e. Etc/UTC or America/Los_Angeles
  -l, --list     List available timezones
EOF
}

function list_timezones() {
  echo "Available timezones:"

  ## systemd-based systems
  if command -v timedatectl >/dev/null 2>&1; then
    timedatectl list-timezones
    return 0
  fi

  ## Fallback: standard Linux zoneinfo directory
  if [[ -d /usr/share/zoneinfo ]]; then
    find /usr/share/zoneinfo -type f \
      ! -path "*/posix/*" \
      ! -path "*/right/*" \
      ! -name ".*" \
      | sed "s|/usr/share/zoneinfo/||" \
      | sort
    return 0
  fi

  ## Alpine / minimal systems fallback
  if command -v ls >/dev/null 2>&1; then
    ls /usr/share/zoneinfo 2>/dev/null || {
      echo "No timezone database found."
      return 1
    }
  fi
}

function set_timezone() {
  local tz="${1:-}"

  if [[ -z "$tz" ]]; then
    echo "[ERROR] Missing --timezone value" >&2
    echo "  Print timezones with ${0} --list-timezones" >&2
    echo "  Run again like: ${0} --timezone Region/City_Name" >&2
    
    return 1
  fi

  echo "Setting timezone to: $tz"

  # systemd systems (Debian, RHEL, Arch, openSUSE, etc.)
  if command -v timedatectl >/dev/null 2>&1; then
    if ! timedatectl list-timezones | grep -qx "$tz"; then
      echo "Invalid timezone: $tz"
      return 1
    fi

    timedatectl set-timezone "$tz"
    echo "Timezone updated via timedatectl"
    date

    return 0
  fi

  # Non-systemd Linux (/etc/localtime symlink)
  if [[ -d /usr/share/zoneinfo ]]; then
    if [[ ! -f "/usr/share/zoneinfo/$tz" ]]; then
      echo "Invalid timezone: $tz"
      return 1
    fi

    ln -sf "/usr/share/zoneinfo/$tz" /etc/localtime

    ## Some systems also use /etc/timezone
    if [[ -f /etc/timezone ]]; then
      echo "$tz" > /etc/timezone
    fi

    echo "Timezone updated via /etc/localtime"
    date

    return 0
  fi

  echo "No supported timezone system found."
  return 1
}

while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      usage
      exit 0
      ;;
    -l|--list-timezones)
      list_timezones
      exit 0
      ;;
    -t|--timezone)
      TZ="$2"
      shift 2
      ;;
    *)
      echo "[ERROR] Invalid arg: $1" >&2
      exit 1
      ;;
  esac
done

set_timezone "${TZ}"

