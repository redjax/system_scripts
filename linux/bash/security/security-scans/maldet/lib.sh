#!/usr/bin/env bash

if [[ "${MALDET_SCRIPTS_LIB_LOADED:-0}" == 1 ]]; then
  return 0
fi
MALDET_SCRIPTS_LIB_LOADED=1

md_log() {
  printf '[maldet] %s\n' "$*" >&2
}

md_die() {
  md_log "ERROR: $*"
  exit 2
}

md_have() {
  command -v "$1" > /dev/null 2>&1
}

md_need_value() {
  [[ $# -ge 2 && -n "$2" ]] ||
    md_die "Missing value for $1"

  case "$2" in
    --*) md_die "Missing value for $1" ;;
  esac
}

md_absolute_path() {
  case "$1" in
    /*) printf '%s\n' "$1" ;;
    *) printf '%s/%s\n' "$PWD" "$1" ;;
  esac
}

md_print_command() {
  printf '+'
  printf ' %q' "$@"
  printf '\n'
}

md_require_linux() {
  [[ "$(uname -s)" == Linux ]] ||
    md_die "This adapter currently supports Linux only."
}

md_require_root() {
  [[ "$EUID" -eq 0 ]] ||
    md_die "Run this operation as root."
}

md_prepare_path() {
  PATH="$PATH:/usr/local/sbin:/usr/sbin:/sbin"
  export PATH
}

md_find_binary() {
  md_have maldet ||
    md_die "maldet not found. Run install.sh first."

  MALDET_BIN="$(command -v maldet)"
  MALDET_BIN="$(md_absolute_path "$MALDET_BIN")"
}

md_require_v2() {
  local version_output

  version_output="$("$MALDET_BIN" --version 2>&1)" ||
    md_die "Unable to query the Maldet version."

  printf '%s\n' "$version_output" |
    grep -Eq 'Linux Malware Detect v?2\.' ||
    md_die "This adapter requires upstream LMD 2.x."

  MALDET_VERSION_OUTPUT="$version_output"
}

md_check_config_safety() {
  local config
  local problems

  ## This adapter supports the standard upstream installation layout.
  [[ -f /usr/local/maldetect/conf.maldet ]] ||
    md_die "Expected upstream configuration: /usr/local/maldetect/conf.maldet"

  for config in \
    /usr/local/maldetect/conf.maldet \
    /etc/sysconfig/maldet \
    /etc/default/maldet; do
    [[ -f "$config" ]] || continue

    ## Do not source configuration in this wrapper.
    #  Reject nonempty hooks/imports rather than executing them or trying
    #  to override protected settings through -co.
    problems="$(
      awk '
        /^[[:space:]]*#/ { next }

        /^[[:space:]]*(export[[:space:]]+)?(post_scan_hook|import_config_url)[[:space:]]*=/ {
          value = $0
          sub(/^[^=]*=/, "", value)
          sub(/[[:space:]]+#.*$/, "", value)
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)

          if (value != "" && value != "\"\"" && value != "\047\047") {
            print FNR ": " $0
          }
        }
      ' "$config"
    )"

    if [[ -n "$problems" ]]; then
      printf '%s\n' "$problems" >&2
      md_die "Configured hook/import requires separate review: $config"
    fi
  done
}

md_capture() {
  local report="$1"
  local verbose="$2"
  shift 2

  MD_NATIVE_RC=0
  MD_WRITER_RC=0

  if [[ "$verbose" -eq 1 ]]; then
    set +e
    "$@" 2>&1 | tee "$report"
    MD_PIPE_CODES=("${PIPESTATUS[@]}")
    set -e

    MD_NATIVE_RC="${MD_PIPE_CODES[0]}"
    MD_WRITER_RC="${MD_PIPE_CODES[1]}"
  else
    : > "$report"
    "$@" > "$report" 2>&1 || MD_NATIVE_RC=$?
  fi
}
