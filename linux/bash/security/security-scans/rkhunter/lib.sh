#!/usr/bin/env bash

if [[ "${RKHUNTER_SCRIPTS_LIB_LOADED:-0}" == 1 ]]; then
  return 0
fi
RKHUNTER_SCRIPTS_LIB_LOADED=1

rkh_log() {
  printf '[rkhunter] %s\n' "$*" >&2
}

rkh_die() {
  rkh_log "ERROR: $*"
  exit 2
}

rkh_have() {
  command -v "$1" > /dev/null 2>&1
}

rkh_need_value() {
  [[ $# -ge 2 && -n "$2" ]] ||
    rkh_die "Missing value for $1"

  case "$2" in
    --*) rkh_die "Missing value for $1" ;;
  esac
}

rkh_absolute_path() {
  case "$1" in
    /*) printf '%s\n' "$1" ;;
    *) printf '%s/%s\n' "$PWD" "$1" ;;
  esac
}

rkh_print_command() {
  printf '+'
  printf ' %q' "$@"
  printf '\n'
}

rkh_run() {
  if [[ "${DRY_RUN:-0}" == 1 ]]; then
    rkh_print_command "$@"
  else
    "$@"
  fi
}

rkh_root() {
  if [[ "$EUID" -eq 0 ]]; then
    rkh_run "$@"
  elif [[ "${DRY_RUN:-0}" == 1 ]]; then
    rkh_print_command sudo "$@"
  else
    rkh_have sudo ||
      rkh_die "Root privileges required; sudo is unavailable."

    sudo -- "$@"
  fi
}

rkh_require_linux() {
  [[ "$(uname -s)" == Linux ]] ||
    rkh_die "This adapter currently supports Linux only."
}

rkh_action_usage() {
  local action="$1"

  cat << EOF
Usage: ${action}.sh [options]

Common options:
  --config FILE      Use an alternate main rkhunter configuration
  --output-dir DIR   Report parent directory
                     Default: /var/log/security-scans/rkhunter
  --verbose          Show full terminal output
  --dry-run          Print the command without executing or writing files
  -h, --help         Show help
EOF

  case "$action" in
    scan)
      cat << 'EOF'

Scan options:
  --enable TESTS     Run selected tests; comma-separated rkhunter names
  --disable TESTS    Disable selected tests; comma-separated names

Scope:
  Inspects the running host, not a supplied directory.
  Does not update detection data or trusted file properties.

Exit codes:
  0  rkhunter returned success
  2  Wrapper/setup/report-writing failure
  3  rkhunter returned nonzero: warnings or errors require review

A zero result is not proof that the host is uncompromised.
EOF
      ;;

    configure)
      cat << 'EOF'

Behavior:
  Validate the existing configuration for its currently enabled tests.
  Do not change configuration, allowlists, or trusted file properties.

Exit codes:
  0  Configuration validation succeeded
  2  Validation or wrapper failure
EOF
      ;;

    update)
      cat << 'EOF'

Behavior:
  Update rkhunter detection/support data.
  Do not update the trusted file-properties baseline.
  Do not upgrade the installed program.

Exit codes:
  0  Update succeeded, including when no update was needed
  2  Update or wrapper failure

Native update code 2 means updates were installed successfully.
Repository-supplied configuration may restrict network updates.
EOF
      ;;

    baseline)
      cat << 'EOF'

Required option:
  --accept-current-state
                     Explicitly trust current tracked file properties

Behavior:
  Run rkhunter --propupd against its configured database.
  No partial baseline updates are implemented by this wrapper.

Only use this after verifying the tracked system files are trustworthy.

Exit codes:
  0  Baseline update succeeded
  2  Baseline update or wrapper failure
EOF
      ;;
  esac

  cat << 'EOF'

Except for dry runs, invoke this script as root.
Reports preserve rkhunter's native exit code.
EOF
}

rkh_action_main() {
  local action="$1"
  shift

  local config=
  local output_dir=/var/log/security-scans/rkhunter
  local verbose=0
  local accept_current_state=0
  local enable_tests=
  local disable_tests=
  local run_dir
  local native_rc
  local writer_rc
  local status
  local exit_code
  local lock_dir=/run/security-scans-rkhunter.lock
  local -a cmd=()
  local -a pipe_codes=()

  DRY_RUN=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --config | --output-dir)
        rkh_need_value "$@"

        case "$1" in
          --config) config="$2" ;;
          --output-dir) output_dir="$2" ;;
        esac

        shift 2
        ;;

      --enable | --disable)
        [[ "$action" == scan ]] ||
          rkh_die "$1 is supported only by scan.sh."

        rkh_need_value "$@"

        case "$1" in
          --enable) enable_tests="$2" ;;
          --disable) disable_tests="$2" ;;
        esac

        shift 2
        ;;

      --accept-current-state)
        [[ "$action" == baseline ]] ||
          rkh_die "$1 is supported only by baseline.sh."

        accept_current_state=1
        shift
        ;;

      --verbose)
        verbose=1
        shift
        ;;

      --dry-run)
        DRY_RUN=1
        shift
        ;;

      -h | --help)
        rkh_action_usage "$action"
        return 0
        ;;

      *)
        rkh_die "Unknown option: $1"
        ;;
    esac
  done

  rkh_require_linux

  if [[ "$action" == baseline &&
    "$accept_current_state" -ne 1 ]]; then
    rkh_die "Baseline updates require --accept-current-state."
  fi

  output_dir="$(rkh_absolute_path "$output_dir")"

  if [[ -n "$config" ]]; then
    config="$(rkh_absolute_path "$config")"

    [[ -f "$config" && -r "$config" ]] ||
      rkh_die "Configuration is missing or unreadable: $config"
  fi

  cmd=(rkhunter --nocolors --no-mail-on-warning)

  if [[ -n "$config" ]]; then
    cmd+=(--configfile "$config")
  fi

  case "$action" in
    configure)
      cmd+=(--config-check)
      ;;
    update)
      cmd+=(--update)
      ;;
    baseline)
      cmd+=(--propupd)
      ;;
    scan)
      cmd+=(--check --skip-keypress)

      if [[ -n "$enable_tests" ]]; then
        cmd+=(--enable "$enable_tests")
      fi

      if [[ -n "$disable_tests" ]]; then
        cmd+=(--disable "$disable_tests")
      fi

      if [[ "$verbose" -eq 0 ]]; then
        cmd+=(--report-warnings-only)
      fi
      ;;
    *)
      rkh_die "Unknown action: $action"
      ;;
  esac

  if [[ "$DRY_RUN" -eq 1 ]]; then
    rkh_log "Would create a unique report directory beneath: $output_dir"

    if [[ "$action" == baseline ]]; then
      rkh_log "Would trust current tracked file properties."
    fi

    rkh_print_command \
      "${cmd[@]}" \
      --logfile '<run-directory>/rkhunter.log'

    return 0
  fi

  [[ "$EUID" -eq 0 ]] ||
    rkh_die "Run this operation as root: sudo ./${action}.sh"

  # Administrative command directories may be absent from user PATH.
  PATH="$PATH:/usr/local/sbin:/usr/sbin:/sbin"
  export PATH

  rkh_have rkhunter ||
    rkh_die "rkhunter not found. Run install.sh first."

  # This lock coordinates these wrappers only.
  if ! mkdir -m 0700 "$lock_dir" 2> /dev/null; then
    rkh_die "Suite lock exists: $lock_dir. Check for another running operation."
  fi

  trap 'rmdir /run/security-scans-rkhunter.lock 2>/dev/null || true' EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM

  umask 077
  mkdir -p "$output_dir"

  run_dir="$(mktemp -d "$output_dir/${action}.XXXXXXXX")"
  cmd+=(--logfile "$run_dir/rkhunter.log")

  rkh_print_command "${cmd[@]}" > "$run_dir/command.txt"

  {
    printf 'action=%s\n' "$action"
    printf 'started_utc=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf 'platform=%s\n' "$(uname -s)"
    printf 'architecture=%s\n' "$(uname -m)"
    printf 'config=%s\n' "${config:-package-default}"
    rkhunter --version
  } > "$run_dir/metadata.txt"

  rkh_log "Action: $action"
  rkh_log "Reports: $run_dir"

  if [[ "$action" == baseline ]]; then
    rkh_log "Recording current tracked file properties as trusted."
  fi

  native_rc=0
  writer_rc=0

  if [[ "$verbose" -eq 1 ]]; then
    set +e
    "${cmd[@]}" 2>&1 | tee "$run_dir/output.log"
    pipe_codes=("${PIPESTATUS[@]}")
    set -e

    native_rc="${pipe_codes[0]}"
    writer_rc="${pipe_codes[1]}"
  else
    # Create the output before executing so redirection failures are
    # wrapper errors, not mistaken for native scan warnings.
    : > "$run_dir/output.log"

    "${cmd[@]}" > "$run_dir/output.log" 2>&1 || native_rc=$?
  fi

  if [[ "$writer_rc" -ne 0 ]]; then
    status=report-error
    exit_code=2
  else
    case "$action" in
      update)
        case "$native_rc" in
          0)
            status=already-current
            exit_code=0
            ;;
          2)
            status=updated
            exit_code=0
            ;;
          *)
            status=update-error
            exit_code=2
            ;;
        esac
        ;;

      scan)
        if [[ "$native_rc" -eq 0 ]]; then
          status=no-warnings-reported
          exit_code=0
        else
          status=review-required
          exit_code=3
        fi
        ;;

      configure | baseline)
        if [[ "$native_rc" -eq 0 ]]; then
          status=success
          exit_code=0
        else
          status=operation-error
          exit_code=2
        fi
        ;;
    esac
  fi

  {
    printf 'tool\taction\tstatus\tnative_exit_code\twriter_exit_code\n'
    printf 'rkhunter\t%s\t%s\t%s\t%s\n' \
      "$action" "$status" "$native_rc" "$writer_rc"
  } > "$run_dir/result.tsv"

  rkh_log "Result: $status"
  rkh_log "Native exit code: $native_rc"

  if [[ "$exit_code" -ne 0 ]]; then
    rkh_log "Review: $run_dir/output.log"
    rkh_log "Detailed log, if created: $run_dir/rkhunter.log"
  fi

  return "$exit_code"
}
