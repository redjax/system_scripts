#!/usr/bin/env bash

if [[ "${LYNIS_SCRIPTS_LIB_LOADED:-0}" == 1 ]]; then
  return 0
fi
LYNIS_SCRIPTS_LIB_LOADED=1

lynis_log() {
  printf '[lynis] %s\n' "$*" >&2
}

lynis_die() {
  lynis_log "ERROR: $*"
  exit 2
}

lynis_have() {
  command -v "$1" >/dev/null 2>&1
}

lynis_need_value() {
  [[ $# -ge 2 && -n "$2" ]] ||
    lynis_die "Missing value for $1"

  case "$2" in
  --*) lynis_die "Missing value for $1" ;;
  esac
}

lynis_absolute_path() {
  case "$1" in
  /*) printf '%s\n' "$1" ;;
  *) printf '%s/%s\n' "$PWD" "$1" ;;
  esac
}

lynis_print_command() {
  printf '+'
  printf ' %q' "$@"
  printf '\n'
}

lynis_run() {
  if [[ "${DRY_RUN:-0}" == 1 ]]; then
    lynis_print_command "$@"
  else
    "$@"
  fi
}

lynis_root() {
  if [[ "$EUID" -eq 0 ]]; then
    lynis_run "$@"
  elif [[ "${DRY_RUN:-0}" == 1 ]]; then
    lynis_print_command sudo "$@"
  else
    lynis_have sudo ||
      lynis_die "Root privileges required; sudo is unavailable."

    sudo -- "$@"
  fi
}

lynis_require_platform() {
  case "$(uname -s)" in
  Linux | Darwin) ;;
  *)
    lynis_die "This adapter supports Linux and macOS only."
    ;;
  esac
}

lynis_prepare_path() {
  ## Preserve the caller's PATH while adding administrative directories.
  PATH="$PATH:/usr/local/sbin:/usr/sbin:/sbin"
  export PATH
}
