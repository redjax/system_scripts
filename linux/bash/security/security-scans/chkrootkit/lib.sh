#!/usr/bin/env bash

if [[ "${CHKROOTKIT_SCRIPTS_LIB_LOADED:-0}" == 1 ]]; then
  return 0
fi
CHKROOTKIT_SCRIPTS_LIB_LOADED=1

chk_log() {
  printf '[chkrootkit] %s\n' "$*" >&2
}

chk_die() {
  chk_log "ERROR: $*"
  exit 2
}

chk_have() {
  command -v "$1" >/dev/null 2>&1
}

chk_need_value() {
  [[ $# -ge 2 && -n "$2" ]] ||
    chk_die "Missing value for $1"

  case "$2" in
  --*) chk_die "Missing value for $1" ;;
  esac
}

chk_absolute_path() {
  case "$1" in
  /*) printf '%s\n' "$1" ;;
  *) printf '%s/%s\n' "$PWD" "$1" ;;
  esac
}

chk_print_command() {
  printf '+'
  printf ' %q' "$@"
  printf '\n'
}

chk_run() {
  if [[ "${DRY_RUN:-0}" == 1 ]]; then
    chk_print_command "$@"
  else
    "$@"
  fi
}

chk_root() {
  if [[ "$EUID" -eq 0 ]]; then
    chk_run "$@"
  elif [[ "${DRY_RUN:-0}" == 1 ]]; then
    chk_print_command sudo "$@"
  else
    chk_have sudo ||
      chk_die "Root privileges required; sudo is unavailable."

    sudo -- "$@"
  fi
}

chk_require_linux() {
  [[ "$(uname -s)" == Linux ]] ||
    chk_die "This adapter currently supports Linux only."
}

chk_prepare_path() {
  PATH="$PATH:/usr/local/sbin:/usr/sbin:/sbin"
  export PATH
}
