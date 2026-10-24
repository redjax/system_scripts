#!/usr/bin/env bash

if [[ "${TRIVY_SCRIPTS_LIB_LOADED:-0}" == 1 ]]; then
  return 0
fi
TRIVY_SCRIPTS_LIB_LOADED=1

tv_log() {
  printf '[trivy] %s\n' "$*" >&2
}

tv_die() {
  tv_log "ERROR: $*"
  exit 2
}

tv_have() {
  command -v "$1" >/dev/null 2>&1
}

tv_need_value() {
  [[ $# -ge 2 && -n "$2" ]] ||
    tv_die "Missing value for $1"

  case "$2" in
  --*) tv_die "Missing value for $1" ;;
  esac
}

tv_absolute_path() {
  case "$1" in
  /*) printf '%s\n' "$1" ;;
  *) printf '%s/%s\n' "$PWD" "$1" ;;
  esac
}

tv_print_command() {
  printf '+'
  printf ' %q' "$@"
  printf '\n'
}

tv_require_platform() {
  case "$(uname -s)" in
  Linux | Darwin) ;;
  *) tv_die "Supported platforms: Linux and macOS." ;;
  esac
}

tv_root() {
  if [[ "$EUID" -eq 0 ]]; then
    "$@"
  else
    tv_have sudo || tv_die "Root privileges required; sudo is unavailable."
    sudo -- "$@"
  fi
}

tv_sha256() {
  if tv_have sha256sum; then
    sha256sum "$1" | awk '{print $1}'
  elif tv_have shasum; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    tv_die "Install sha256sum or shasum."
  fi
}
