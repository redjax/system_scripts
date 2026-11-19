#!/usr/bin/env bash

if [[ "${CLAMAV_SCRIPTS_LIB_LOADED:-0}" == 1 ]]; then
  return 0
fi
CLAMAV_SCRIPTS_LIB_LOADED=1

## Include standard administrative command directories.
#  Keep existing entries so nonstandard installations remain discoverable.
PATH="${PATH:-/usr/local/bin:/usr/bin:/bin}:/usr/local/sbin:/usr/sbin:/sbin"
export PATH

clam_log() {
  printf '[clamav] %s\n' "$*" >&2
}

clam_die() {
  clam_log "ERROR: $*"
  exit 2
}

clam_have() {
  command -v "$1" > /dev/null 2>&1
}

clam_need_value() {
  [[ $# -ge 2 && -n "$2" ]] ||
    clam_die "Missing value for $1"

  case "$2" in
    --*) clam_die "Missing value for $1" ;;
  esac
}

clam_default_database() {
  printf '%s\n' \
    "${XDG_CACHE_HOME:-$HOME/.cache}/security-scans/clamav/db"
}

clam_absolute_path() {
  case "$1" in
    /*) printf '%s\n' "$1" ;;
    *) printf '%s/%s\n' "$PWD" "$1" ;;
  esac
}

clam_print_command() {
  printf '+'
  printf ' %q' "$@"
  printf '\n'
}

clam_run() {
  if [[ "${DRY_RUN:-0}" == 1 ]]; then
    clam_print_command "$@"
  else
    "$@"
  fi
}

clam_root() {
  if [[ "$EUID" -eq 0 ]]; then
    clam_run "$@"
  elif [[ "${DRY_RUN:-0}" == 1 ]]; then
    clam_print_command sudo "$@"
  else
    clam_have sudo ||
      clam_die "Root privileges required; sudo is unavailable"
    sudo -- "$@"
  fi
}

clam_root_script() {
  local script="$1"
  shift

  if [[ "$EUID" -eq 0 ]]; then
    /bin/bash "$script" "$@"
  else
    clam_have sudo ||
      clam_die "Root privileges required; sudo is unavailable."

    sudo -- /bin/bash "$script" "$@"
  fi
}
