#!/usr/bin/env bash
set -euo pipefail
umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'EOF'
Usage:
  scan.sh --all [options]
  scan.sh --scanners LIST [options]

Selection:
  --all                       Run all supported adapters for this platform
  --scanners            LIST  Comma-separated names: clamav,rkhunter,chkrootkit,lynis,maldet
  --tools               LIST  Alias for --scanners
  --list                      List adapter support and script availability

File-scan scope:
  --target              PATH   Target for ClamAV and Maldet; repeatable. Required when either file scanner is selected
  --clamav-database     DIR    ClamAV signature directory. Default: invoking user's XDG cache database
  --clamav-exclude-dir  REGEX  ClamAV directory exclusion; repeatable
  --maldet-engine       NAME   'native' or 'clamav'. Default: native

Lynis:
  --lynis-bin           FILE   Explicit Lynis executable path. Useful for Homebrew with sudo
  --lynis-profile       FILE   Alternate Lynis profile

Execution:
  --sudo                       Elevate adapter commands when not already root
  --output-dir          DIR    Parent directory for orchestration reports. Default: ./security-scan-reports
  --verbose                    Stream adapter output while saving it
  --dry-run                    Show commands without executing or writing reports
  -h, --help                   Show help

Behavior:
  - Run sequentially in requested order
  - Run host scanners once
  - Run ClamAV and Maldet once per target
  - Continue after adapter failures and findings
  - Do not install tools or update signatures
  - Do not establish baselines or remediate findings
  - "all" excludes adapters unsupported by this suite on the platform
  - Missing selected adapter scripts are errors, not silent skips

Scope:
  - Targets apply only to ClamAV and Maldet.
  - rkhunter, chkrootkit, and Lynis inspect the running host.
  - File-scanner limits and ignore settings remain adapter-controlled.

Exit codes:
  0  All adapters returned their success status
  1  At least one file scanner reported malware hits
  2  At least one adapter/setup/report failure
  3  At least one adapter requires review

Precedence:
  error > malware hits > review required > success

Success does not mean the host is uncompromised.
Results preserve each adapter's exit code.

Examples:
  ./scan.sh --scanners clamav --target "$HOME/Downloads"

  ./scan.sh --scanners rkhunter,chkrootkit,lynis --sudo --verbose

  ./scan.sh --all --target /var/www --sudo

  ./scan.sh --all --target "$HOME/projects" --dry-run
EOF
}

log() {
  printf '[security-scans] %s\n' "$*" >&2
}

die() {
  log "ERROR: $*"
  exit 2
}

have() {
  command -v "$1" >/dev/null 2>&1
}

need_value() {
  [[ $# -ge 2 && -n "$2" ]] ||
    die "Missing value for $1"

  case "$2" in
  --*) die "Missing value for $1" ;;
  esac
}

absolute_path() {
  case "$1" in
  /*) printf '%s\n' "$1" ;;
  *) printf '%s/%s\n' "$PWD" "$1" ;;
  esac
}

print_command() {
  printf '+'
  printf ' %q' "$@"
  printf '\n'
}

supported() {
  case "$PLATFORM:$1" in
  Linux:clamav | Linux:rkhunter | Linux:chkrootkit | \
    Linux:lynis | Linux:maldet | Darwin:clamav | Darwin:lynis)
    return 0
    ;;
  *)
    return 1
    ;;
  esac
}

is_file_scanner() {
  case "$1" in
  clamav | maldet) return 0 ;;
  *) return 1 ;;
  esac
}

ALL_SCANNERS=(clamav rkhunter chkrootkit lynis maldet)
SCANNERS=()
TARGETS=()
CLAMAV_EXCLUDES=()

SELECTION=
SELECT_ALL=0
LIST_ONLY=0
USE_SUDO=0
VERBOSE=0
DRY_RUN=0
OUTPUT_DIR="$PWD/security-scan-reports"
CLAMAV_DATABASE=
MALDET_ENGINE=native
LYNIS_BIN=
LYNIS_PROFILE=

while [[ $# -gt 0 ]]; do
  case "$1" in
  --all)
    SELECT_ALL=1
    shift
    ;;

  --scanners | --tools | --target | --output-dir | \
    --clamav-database | --clamav-exclude-dir | \
    --maldet-engine | --lynis-bin | --lynis-profile)
    need_value "$@"

    case "$1" in
    --scanners | --tools) SELECTION="$2" ;;
    --target) TARGETS+=("$2") ;;
    --output-dir) OUTPUT_DIR="$2" ;;
    --clamav-database) CLAMAV_DATABASE="$2" ;;
    --clamav-exclude-dir) CLAMAV_EXCLUDES+=("$2") ;;
    --maldet-engine) MALDET_ENGINE="$2" ;;
    --lynis-bin) LYNIS_BIN="$2" ;;
    --lynis-profile) LYNIS_PROFILE="$2" ;;
    esac

    shift 2
    ;;

  --list)
    LIST_ONLY=1
    shift
    ;;

  --sudo)
    USE_SUDO=1
    shift
    ;;

  --verbose)
    VERBOSE=1
    shift
    ;;

  --dry-run)
    DRY_RUN=1
    shift
    ;;

  -h | --help)
    usage
    exit 0
    ;;

  *)
    die "Unknown option: $1"
    ;;
  esac
done

PLATFORM="$(uname -s)"

case "$PLATFORM" in
Linux | Darwin) ;;
*) die "Unsupported platform: $PLATFORM" ;;
esac

if [[ "$LIST_ONLY" -eq 1 ]]; then
  printf 'scanner\tplatform_supported\tadapter_present\n'

  for scanner in "${ALL_SCANNERS[@]}"; do
    PLATFORM_SUPPORTED=no
    ADAPTER_PRESENT=no

    if supported "$scanner"; then
      PLATFORM_SUPPORTED=yes
    fi

    if [[ -f "$SCRIPT_DIR/$scanner/scan.sh" ]]; then
      ADAPTER_PRESENT=yes
    fi

    printf '%s\t%s\t%s\n' \
      "$scanner" "$PLATFORM_SUPPORTED" "$ADAPTER_PRESENT"
  done

  exit 0
fi

if [[ "$SELECT_ALL" -eq 1 && -n "$SELECTION" ]]; then
  die "Choose --all or --scanners, not both."
fi

if [[ "$SELECT_ALL" -eq 1 ]]; then
  for scanner in "${ALL_SCANNERS[@]}"; do
    if supported "$scanner"; then
      SCANNERS+=("$scanner")
    fi
  done
else
  [[ -n "$SELECTION" ]] ||
    die "Specify --all or --scanners LIST."

  case "$SELECTION" in
  ,* | *, | *,,*)
    die "Invalid scanner list: $SELECTION"
    ;;
  esac

  REQUESTED=()
  IFS=',' read -r -a REQUESTED <<<"$SELECTION"

  for scanner in "${REQUESTED[@]}"; do
    case "$scanner" in
    clamav | rkhunter | chkrootkit | lynis | maldet) ;;
    *) die "Unknown scanner: $scanner" ;;
    esac

    supported "$scanner" ||
      die "$scanner is not enabled by this suite for $PLATFORM."

    case " ${SCANNERS[*]:-} " in
    *" $scanner "*) ;;
    *) SCANNERS+=("$scanner") ;;
    esac
  done
fi

HAS_FILE_SCANNER=0
HAS_CLAMAV=0
NEEDS_ROOT=0

for scanner in "${SCANNERS[@]}"; do
  if is_file_scanner "$scanner"; then
    HAS_FILE_SCANNER=1
  fi

  if [[ "$scanner" == clamav ]]; then
    HAS_CLAMAV=1
  else
    NEEDS_ROOT=1
  fi
done

if [[ "$HAS_FILE_SCANNER" -eq 1 && ${#TARGETS[@]} -eq 0 ]]; then
  die "Selected file scanners require at least one --target."
fi

if [[ "$HAS_FILE_SCANNER" -eq 0 && ${#TARGETS[@]} -gt 0 ]]; then
  die "--target applies only to ClamAV and Maldet."
fi

for ((i = 0; i < ${#TARGETS[@]}; i++)); do
  TARGETS[$i]="$(absolute_path "${TARGETS[$i]}")"

  [[ -f "${TARGETS[$i]}" || -d "${TARGETS[$i]}" ]] ||
    die "Target is not an existing file or directory: ${TARGETS[$i]}"

  ## Keep TSV summaries unambiguous.
  case "${TARGETS[$i]}" in
  *$'\t'* | *$'\n'* | *$'\r'*)
    die "Target contains unsupported tab or newline characters."
    ;;
  esac
done

case "$MALDET_ENGINE" in
native | clamav) ;;
*) die "--maldet-engine must be native or clamav." ;;
esac

if [[ "$HAS_CLAMAV" -eq 1 ]]; then
  if [[ -z "$CLAMAV_DATABASE" ]]; then
    if [[ "$EUID" -eq 0 &&
      -n "${SUDO_USER:-}" &&
      "$SUDO_USER" != root ]]; then
      die "When launching this orchestrator with sudo, specify --clamav-database. Alternatively run as your normal user with --sudo."
    fi

    CLAMAV_DATABASE="${XDG_CACHE_HOME:-$HOME/.cache}/security-scans/clamav/db"
  fi

  ## Resolve before elevating any adapter.
  CLAMAV_DATABASE="$(absolute_path "$CLAMAV_DATABASE")"
fi

if [[ -n "$LYNIS_BIN" ]]; then
  LYNIS_BIN="$(absolute_path "$LYNIS_BIN")"

  [[ -f "$LYNIS_BIN" && -x "$LYNIS_BIN" ]] ||
    die "Lynis executable is missing or not executable: $LYNIS_BIN"
elif [[ "$PLATFORM" == Darwin ]] && have lynis; then
  ## Preserve the Homebrew executable path before sudo changes PATH.
  LYNIS_BIN="$(absolute_path "$(command -v lynis)")"
fi

if [[ -n "$LYNIS_PROFILE" ]]; then
  LYNIS_PROFILE="$(absolute_path "$LYNIS_PROFILE")"

  [[ -f "$LYNIS_PROFILE" && -r "$LYNIS_PROFILE" ]] ||
    die "Lynis profile is missing or unreadable: $LYNIS_PROFILE"
fi

OUTPUT_DIR="$(absolute_path "$OUTPUT_DIR")"

if [[ "$NEEDS_ROOT" -eq 1 &&
  "$EUID" -ne 0 &&
  "$USE_SUDO" -ne 1 ]]; then
  die "Selected host/Maldet adapters require root. Run as your normal user with --sudo."
fi

if [[ "$USE_SUDO" -eq 1 && "$EUID" -ne 0 &&
  "$DRY_RUN" -eq 0 ]]; then
  have sudo || die "--sudo requested, but sudo is unavailable."

  ## Authenticate before starting the batch.
  sudo -v
fi

RUN_DIR=
SUMMARY=
ERRORS=0
HITS=0
REVIEWS=0
SUCCESSES=0
JOB_NUMBER=0

if [[ "$DRY_RUN" -eq 0 ]]; then
  mkdir -p "$OUTPUT_DIR"
  RUN_DIR="$(mktemp -d "$OUTPUT_DIR/run.XXXXXXXX")"
  SUMMARY="$RUN_DIR/summary.tsv"

  printf 'job\tscanner\tscope\tstatus\tadapter_exit_code\toutput_log\n' \
    >"$SUMMARY"

  {
    printf 'started_utc=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf 'platform=%s\n' "$PLATFORM"
    printf 'architecture=%s\n' "$(uname -m)"
    printf 'scanners=%s\n' "${SCANNERS[*]}"
    printf 'sudo_requested=%s\n' "$USE_SUDO"
  } >"$RUN_DIR/metadata.txt"

  log "Batch reports: $RUN_DIR"
fi

## Adapters remain responsible for their own native-tool locking.
#  These traps stop the batch rather than continue after interruption.
trap 'exit 130' INT
trap 'exit 143' TERM

classify_result() {
  local scanner="$1"
  local rc="$2"

  JOB_STATUS=error

  case "$scanner:$rc" in
  clamav:0 | maldet:0 | rkhunter:0)
    JOB_STATUS=completed
    ;;

  clamav:1 | maldet:1)
    JOB_STATUS=malware-hits
    ;;

  rkhunter:3 | chkrootkit:3 | lynis:3)
    JOB_STATUS=review-required
    ;;
  esac
}

run_job() {
  local scanner="$1"
  local scope="$2"
  local adapter="$SCRIPT_DIR/$scanner/scan.sh"
  local job_dir
  local rc=0
  local writer_rc=0
  local -a args=()
  local -a command=()
  local -a pipe_codes=()

  JOB_NUMBER=$((JOB_NUMBER + 1))

  if [[ "$DRY_RUN" -eq 1 ]]; then
    job_dir="$OUTPUT_DIR/<batch>/job-$JOB_NUMBER-$scanner"
  else
    job_dir="$RUN_DIR/job-$JOB_NUMBER-$scanner"
    mkdir -p "$job_dir"
  fi

  case "$scanner" in
  clamav)
    args+=(
      --target "$scope"
      --database "$CLAMAV_DATABASE"
      --output-dir "$job_dir/reports"
    )

    for regex in "${CLAMAV_EXCLUDES[@]}"; do
      args+=(--exclude-dir "$regex")
    done
    ;;

  maldet)
    args+=(
      --target "$scope"
      --engine "$MALDET_ENGINE"
      --output-dir "$job_dir/reports"
    )
    ;;

  rkhunter | chkrootkit)
    args+=(--output-dir "$job_dir/reports")
    ;;

  lynis)
    args+=(--output-dir "$job_dir/reports")

    if [[ -n "$LYNIS_BIN" ]]; then
      args+=(--lynis-bin "$LYNIS_BIN")
    fi

    if [[ -n "$LYNIS_PROFILE" ]]; then
      args+=(--profile "$LYNIS_PROFILE")
    fi
    ;;
  esac

  ## Ask child adapters to include native terminal output in the
  #  captured orchestration log. The parent controls live streaming.
  if [[ "$scanner" != clamav ]]; then
    args+=(--verbose)
  fi

  command=(/bin/bash "$adapter" "${args[@]}")

  if [[ "$USE_SUDO" -eq 1 && "$EUID" -ne 0 ]]; then
    command=(sudo -- "${command[@]}")
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "[$JOB_NUMBER] $scanner: $scope"

    if [[ ! -f "$adapter" ]]; then
      log "ERROR: Missing adapter: $adapter"
      ERRORS=$((ERRORS + 1))
    fi

    print_command "${command[@]}"
    return 0
  fi

  print_command "${command[@]}" >"$job_dir/command.txt"
  log "[$JOB_NUMBER] Starting $scanner: $scope"

  if [[ ! -f "$adapter" ]]; then
    printf 'Missing adapter: %s\n' "$adapter" >"$job_dir/output.log"
    rc=127
  elif [[ "$VERBOSE" -eq 1 ]]; then
    set +e
    "${command[@]}" 2>&1 | tee "$job_dir/output.log"
    pipe_codes=("${PIPESTATUS[@]}")
    set -e

    rc="${pipe_codes[0]}"
    writer_rc="${pipe_codes[1]}"
  else
    : >"$job_dir/output.log"
    "${command[@]}" >"$job_dir/output.log" 2>&1 || rc=$?
  fi

  ## Do not turn interruption into an ordinary adapter error.
  case "$rc" in
  130 | 143)
    log "Interrupted; partial reports remain in $RUN_DIR"
    exit "$rc"
    ;;
  esac

  classify_result "$scanner" "$rc"

  if [[ "$writer_rc" -ne 0 ]]; then
    JOB_STATUS=report-error
  fi

  case "$JOB_STATUS" in
  completed)
    SUCCESSES=$((SUCCESSES + 1))
    ;;
  malware-hits)
    HITS=$((HITS + 1))
    ;;
  review-required)
    REVIEWS=$((REVIEWS + 1))
    ;;
  *)
    ERRORS=$((ERRORS + 1))
    ;;
  esac

  {
    printf 'adapter_exit_code=%s\n' "$rc"
    printf 'writer_exit_code=%s\n' "$writer_rc"
  } >"$job_dir/status.txt"

  printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$JOB_NUMBER" \
    "$scanner" \
    "$scope" \
    "$JOB_STATUS" \
    "$rc" \
    "$job_dir/output.log" \
    >>"$SUMMARY"

  log "[$JOB_NUMBER] $scanner: $JOB_STATUS (adapter exit $rc)"
}

for scanner in "${SCANNERS[@]}"; do
  if is_file_scanner "$scanner"; then
    for target in "${TARGETS[@]}"; do
      run_job "$scanner" "$target"
    done
  else
    run_job "$scanner" host
  fi
done

if [[ "$DRY_RUN" -eq 1 ]]; then
  log "Dry run complete: $JOB_NUMBER planned jobs."

  if [[ "$ERRORS" -gt 0 ]]; then
    exit 2
  fi

  exit 0
fi

printf '\n'
printf 'Security scan batch summary\n'
printf '  Jobs:             %s\n' "$JOB_NUMBER"
printf '  Completed:        %s\n' "$SUCCESSES"
printf '  Malware-hit jobs: %s\n' "$HITS"
printf '  Review required:  %s\n' "$REVIEWS"
printf '  Errors:           %s\n' "$ERRORS"
printf '  Summary:          %s\n' "$SUMMARY"

if [[ "$ERRORS" -gt 0 ]]; then
  exit 2
elif [[ "$HITS" -gt 0 ]]; then
  exit 1
elif [[ "$REVIEWS" -gt 0 ]]; then
  exit 3
else
  exit 0
fi
