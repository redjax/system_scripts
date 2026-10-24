#!/usr/bin/env bash
set -euo pipefail
umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'EOF'
Usage:
  run-scans.sh --all [options]
  run-scans.sh --scanners LIST [options]

Selection:
  --all                             Run all supported adapters for this platform
  --scanners              LIST      Comma-separated names: clamav,rkhunter,chkrootkit,lynis,maldet,trivy
  --tools                 LIST      Alias for --scanners.
  --list                            List adapter support and script availability

Filesystem scope:
  --target                PATH      Repeatable filesystem target. Used by ClamAV, Maldet, and Trivy filesystem/rootfs modes

ClamAV:
  --clamav-database       DIR       Signature directory. Default: invoking user's XDG cache database
  --clamav-exclude-dir    REGEX     Repeatable directory exclusion

Maldet:
  --maldet-engine         NAME      'native' or 'clamav';. Default: native

Lynis:
  --lynis-bin             FILE      Explicit Lynis executable path
  --lynis-profile         FILE      Alternate Lynis profile

Trivy:
  --trivy-mode            MODE      'filesystem', 'rootfs', or 'image'. Default: filesystem
  --image                 REF       Repeatable image reference for image mode.
  --trivy-scanners        LIST      'vuln', 'secret', 'misconfig'. Default: vuln
  --trivy-severity        LIST      Comma-separated severities. Default: UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL
  --trivy-ignore-unfixed            Filter vulnerabilities without a known fix
  --trivy-ignorefile      FILE      Explicit ignore file
  --trivy-config          FILE      Explicit main configuration
  --trivy-skip-dir        PATH      Repeatable directory/pattern exclusion
  --trivy-cache-dir       DIR       Explicit database/cache directory
  --trivy-bin             FILE      Explicit executable path
  --trivy-timeout         DURATION  Scan timeout, e.g. 30s, 15m, or 1h. Default: 15m

Execution:
  --sudo                            Elevate all adapter commands when not root
  --output-dir            DIR       Batch report parent directory. Default: ./security-scan-reports
  --verbose                         Stream adapter output while saving it
  --dry-run                         Print commands without executing/writing reports
  -h, --help                        Show help

Behavior:
  - Run sequentially in requested order
  - Run host scanners once
  - Run filesystem scanners once per target
  - Run Trivy image mode once per image reference
  - Continue after adapter failures and findings
  - Do not install tools, accept baselines, or remediate findings
  - Do not explicitly invoke signature-update scripts
  - Trivy may download/refresh databases as part of its normal scan
  - "all" excludes adapters unsupported by this suite on the platform
  - Missing selected adapters are errors, not silent skips

Scope:
  - rkhunter, chkrootkit, and Lynis inspect the running host
  - Trivy filesystem/rootfs modes require directory targets
  - Trivy rootfs mode is enabled only on Linux and requires elevation here
  - Trivy image mode requires --image and does not consume --target
  - Other scanner limits and ignore settings remain adapter-controlled

Privileges:
  --sudo elevates every adapter, including Trivy image scans.
  Elevated image scans may use root's registry/runtime credentials and cache.
  Run Trivy image-only batches without --sudo when elevation is unnecessary.

Exit codes:
  0  All adapters returned their supported success status
  1  At least one malware-hit or Trivy security-finding job
  2  At least one adapter/setup/report failure
  3  At least one adapter requires review

Precedence:
  error > findings > review required > success

Success does not mean the host is uncompromised.
Each adapter's exit code is preserved.

Examples:
  ./run-scans.sh --all --target /var/www --sudo

  ./run-scans.sh --scanners trivy \
    --target /srv/my-app --verbose

  ./run-scans.sh --scanners trivy \
    --trivy-mode rootfs --target / --sudo

  ./run-scans.sh --scanners trivy \
    --trivy-mode image --image example/app:tag

  ./run-scans.sh --scanners rkhunter,chkrootkit,lynis \
    --sudo --verbose
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

validate_summary_value() {
  case "$1" in
  *$'\t'* | *$'\n'* | *$'\r'*)
    die "Scope contains unsupported tab or newline characters."
    ;;
  esac
}

validate_list() {
  local list="$1"
  local kind="$2"
  local item
  local -a items=()

  case "$list" in
  "" | ,* | *, | *,,*)
    die "Invalid $kind list: $list"
    ;;
  esac

  IFS=',' read -r -a items <<<"$list"

  for item in "${items[@]}"; do
    case "$kind:$item" in
    trivy-scanners:vuln | trivy-scanners:secret | \
      trivy-scanners:misconfig | \
      trivy-severity:UNKNOWN | trivy-severity:LOW | \
      trivy-severity:MEDIUM | trivy-severity:HIGH | \
      trivy-severity:CRITICAL) ;;
    *)
      die "Unsupported $kind value: $item"
      ;;
    esac
  done
}

supported() {
  case "$PLATFORM:$1" in
  Linux:clamav | Linux:rkhunter | Linux:chkrootkit | \
    Linux:lynis | Linux:maldet | Linux:trivy | \
    Darwin:clamav | Darwin:lynis | Darwin:trivy)
    return 0
    ;;
  *)
    return 1
    ;;
  esac
}

uses_targets() {
  case "$1" in
  clamav | maldet)
    return 0
    ;;
  trivy)
    [[ "$TRIVY_MODE" != image ]]
    ;;
  *)
    return 1
    ;;
  esac
}

ALL_SCANNERS=(clamav rkhunter chkrootkit lynis maldet trivy)
SCANNERS=()
TARGETS=()
IMAGES=()
CLAMAV_EXCLUDES=()
TRIVY_SKIP_DIRS=()

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

TRIVY_MODE=filesystem
TRIVY_SCANNERS=vuln
TRIVY_SEVERITY=UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL
TRIVY_IGNORE_UNFIXED=0
TRIVY_IGNOREFILE=
TRIVY_CONFIG=
TRIVY_CACHE_DIR=
TRIVY_BIN=
TRIVY_OPTIONS_SET=0
TRIVY_TIMEOUT=15m

while [[ $# -gt 0 ]]; do
  case "$1" in
  --all)
    SELECT_ALL=1
    shift
    ;;

  --scanners | --tools | --target | --image | --output-dir | \
    --clamav-database | --clamav-exclude-dir | --maldet-engine | \
    --lynis-bin | --lynis-profile | --trivy-mode | --trivy-scanners | \
    --trivy-severity | --trivy-ignorefile | --trivy-config | \
    --trivy-skip-dir | --trivy-cache-dir | --trivy-bin | --trivy-timeout)
    need_value "$@"

    case "$1" in
    --scanners | --tools) SELECTION="$2" ;;
    --target) TARGETS+=("$2") ;;
    --image) IMAGES+=("$2") ;;
    --output-dir) OUTPUT_DIR="$2" ;;
    --clamav-database) CLAMAV_DATABASE="$2" ;;
    --clamav-exclude-dir) CLAMAV_EXCLUDES+=("$2") ;;
    --maldet-engine) MALDET_ENGINE="$2" ;;
    --lynis-bin) LYNIS_BIN="$2" ;;
    --lynis-profile) LYNIS_PROFILE="$2" ;;
    --trivy-mode) TRIVY_MODE="$2" ;;
    --trivy-scanners) TRIVY_SCANNERS="$2" ;;
    --trivy-severity) TRIVY_SEVERITY="$2" ;;
    --trivy-ignorefile) TRIVY_IGNOREFILE="$2" ;;
    --trivy-config) TRIVY_CONFIG="$2" ;;
    --trivy-skip-dir) TRIVY_SKIP_DIRS+=("$2") ;;
    --trivy-cache-dir) TRIVY_CACHE_DIR="$2" ;;
    --trivy-bin) TRIVY_BIN="$2" ;;
    --trivy-timeout) TRIVY_TIMEOUT="$2" ;;
    esac

    case "$1" in
    --trivy-*) TRIVY_OPTIONS_SET=1 ;;
    esac

    shift 2
    ;;

  --trivy-ignore-unfixed)
    TRIVY_IGNORE_UNFIXED=1
    TRIVY_OPTIONS_SET=1
    shift
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
    clamav | rkhunter | chkrootkit | lynis | maldet | trivy) ;;
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

case "$TRIVY_MODE" in
filesystem | rootfs | image) ;;
*) die "--trivy-mode must be filesystem, rootfs, or image." ;;
esac

HAS_TARGET_SCANNER=0
HAS_CLAMAV=0
HAS_TRIVY=0
NEEDS_ROOT=0

for scanner in "${SCANNERS[@]}"; do
  if uses_targets "$scanner"; then
    HAS_TARGET_SCANNER=1
  fi

  case "$scanner" in
  clamav)
    HAS_CLAMAV=1
    ;;
  rkhunter | chkrootkit | lynis | maldet)
    NEEDS_ROOT=1
    ;;
  trivy)
    HAS_TRIVY=1

    if [[ "$TRIVY_MODE" == rootfs ]]; then
      NEEDS_ROOT=1
    fi
    ;;
  esac
done

if [[ "$HAS_TRIVY" -eq 0 ]]; then
  if [[ "$TRIVY_OPTIONS_SET" -eq 1 || ${#IMAGES[@]} -gt 0 ]]; then
    die "Trivy options and --image require selecting trivy."
  fi
else
  validate_list "$TRIVY_SCANNERS" trivy-scanners
  validate_list "$TRIVY_SEVERITY" trivy-severity

  [[ "$TRIVY_TIMEOUT" =~ ^[1-9][0-9]*[smh]$ ]] ||
    die "--trivy-timeout must be a positive duration such as 30s, 15m, or 1h."

  if [[ "$TRIVY_MODE" == rootfs && "$PLATFORM" != Linux ]]; then
    die "Trivy rootfs mode is enabled only on Linux."
  fi

  if [[ "$TRIVY_MODE" == image ]]; then
    [[ ${#IMAGES[@]} -gt 0 ]] ||
      die "Trivy image mode requires at least one --image."
  elif [[ ${#IMAGES[@]} -gt 0 ]]; then
    die "--image requires --trivy-mode image."
  fi
fi

if [[ "$HAS_TARGET_SCANNER" -eq 1 && ${#TARGETS[@]} -eq 0 ]]; then
  die "Selected filesystem scanners require at least one --target."
fi

if [[ "$HAS_TARGET_SCANNER" -eq 0 && ${#TARGETS[@]} -gt 0 ]]; then
  die "--target is not consumed by the selected scanners/modes."
fi

for ((i = 0; i < ${#TARGETS[@]}; i++)); do
  TARGETS[$i]="$(absolute_path "${TARGETS[$i]}")"

  [[ -f "${TARGETS[$i]}" || -d "${TARGETS[$i]}" ]] ||
    die "Target is not an existing file or directory: ${TARGETS[$i]}"

  validate_summary_value "${TARGETS[$i]}"

  if [[ "$HAS_TRIVY" -eq 1 && "$TRIVY_MODE" != image ]]; then
    [[ -d "${TARGETS[$i]}" ]] ||
      die "Trivy $TRIVY_MODE requires directory targets: ${TARGETS[$i]}"
  fi
done

for image in "${IMAGES[@]}"; do
  [[ -n "$image" && "$image" != -* ]] ||
    die "Invalid image reference: $image"

  validate_summary_value "$image"
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
      die "When launching with sudo, specify --clamav-database. Alternatively run as your normal user with --sudo."
    fi

    CLAMAV_DATABASE="${XDG_CACHE_HOME:-$HOME/.cache}/security-scans/clamav/db"
  fi

  CLAMAV_DATABASE="$(absolute_path "$CLAMAV_DATABASE")"
fi

if [[ -n "$LYNIS_BIN" ]]; then
  LYNIS_BIN="$(absolute_path "$LYNIS_BIN")"

  [[ -f "$LYNIS_BIN" && -x "$LYNIS_BIN" ]] ||
    die "Lynis executable is missing or not executable: $LYNIS_BIN"
elif [[ "$PLATFORM" == Darwin ]] && have lynis; then
  LYNIS_BIN="$(absolute_path "$(command -v lynis)")"
fi

if [[ -n "$LYNIS_PROFILE" ]]; then
  LYNIS_PROFILE="$(absolute_path "$LYNIS_PROFILE")"

  [[ -f "$LYNIS_PROFILE" && -r "$LYNIS_PROFILE" ]] ||
    die "Lynis profile is missing or unreadable: $LYNIS_PROFILE"
fi

if [[ "$HAS_TRIVY" -eq 1 ]]; then
  if [[ -n "$TRIVY_BIN" ]]; then
    TRIVY_BIN="$(absolute_path "$TRIVY_BIN")"

    [[ -f "$TRIVY_BIN" && -x "$TRIVY_BIN" ]] ||
      die "Trivy executable is missing or not executable: $TRIVY_BIN"
  elif have trivy; then
    # Resolve before elevation changes the executable search path.
    TRIVY_BIN="$(absolute_path "$(command -v trivy)")"
  fi

  if [[ -n "$TRIVY_CONFIG" ]]; then
    TRIVY_CONFIG="$(absolute_path "$TRIVY_CONFIG")"

    [[ -f "$TRIVY_CONFIG" && -r "$TRIVY_CONFIG" ]] ||
      die "Trivy config is missing or unreadable: $TRIVY_CONFIG"
  fi

  if [[ -n "$TRIVY_IGNOREFILE" ]]; then
    TRIVY_IGNOREFILE="$(absolute_path "$TRIVY_IGNOREFILE")"

    [[ -f "$TRIVY_IGNOREFILE" && -r "$TRIVY_IGNOREFILE" ]] ||
      die "Trivy ignore file is missing or unreadable: $TRIVY_IGNOREFILE"
  fi

  if [[ -n "$TRIVY_CACHE_DIR" ]]; then
    TRIVY_CACHE_DIR="$(absolute_path "$TRIVY_CACHE_DIR")"
  fi
fi

OUTPUT_DIR="$(absolute_path "$OUTPUT_DIR")"

if [[ "$NEEDS_ROOT" -eq 1 &&
  "$EUID" -ne 0 &&
  "$USE_SUDO" -ne 1 ]]; then
  die "Selected adapters/modes require root. Run as your normal user with --sudo."
fi

if [[ "$USE_SUDO" -eq 1 &&
  "$EUID" -ne 0 &&
  "$DRY_RUN" -eq 0 ]]; then
  have sudo || die "--sudo requested, but sudo is unavailable."
  sudo -v
fi

RUN_DIR=
SUMMARY=
ERRORS=0
HITS=0
SECURITY_FINDINGS=0
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

    if [[ "$HAS_TRIVY" -eq 1 ]]; then
      printf 'trivy_mode=%s\n' "$TRIVY_MODE"
      printf 'trivy_scanners=%s\n' "$TRIVY_SCANNERS"
      printf 'trivy_severity=%s\n' "$TRIVY_SEVERITY"
      printf 'trivy_timeout=%s\n' "$TRIVY_TIMEOUT"
    fi
  } >"$RUN_DIR/metadata.txt"

  log "Batch reports: $RUN_DIR"
fi

trap 'exit 130' INT
trap 'exit 143' TERM

classify_result() {
  local scanner="$1"
  local rc="$2"

  JOB_STATUS=error

  case "$scanner:$rc" in
  clamav:0 | maldet:0 | rkhunter:0 | trivy:0)
    JOB_STATUS=completed
    ;;

  clamav:1 | maldet:1)
    JOB_STATUS=malware-hits
    ;;

  trivy:1)
    JOB_STATUS=security-findings
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
  local regex
  local skip_dir
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

  trivy)
    args+=(
      --mode "$TRIVY_MODE"
      --scanners "$TRIVY_SCANNERS"
      --severity "$TRIVY_SEVERITY"
      --timeout "$TRIVY_TIMEOUT"
      --output-dir "$job_dir/reports"
    )

    if [[ "$TRIVY_MODE" == image ]]; then
      args+=(--image "$scope")
    else
      args+=(--target "$scope")
    fi

    if [[ "$TRIVY_IGNORE_UNFIXED" -eq 1 ]]; then
      args+=(--ignore-unfixed)
    fi

    if [[ -n "$TRIVY_BIN" ]]; then
      args+=(--trivy-bin "$TRIVY_BIN")
    fi

    if [[ -n "$TRIVY_CONFIG" ]]; then
      args+=(--config "$TRIVY_CONFIG")
    fi

    if [[ -n "$TRIVY_IGNOREFILE" ]]; then
      args+=(--ignorefile "$TRIVY_IGNOREFILE")
    fi

    if [[ -n "$TRIVY_CACHE_DIR" ]]; then
      args+=(--cache-dir "$TRIVY_CACHE_DIR")
    fi

    for skip_dir in "${TRIVY_SKIP_DIRS[@]}"; do
      args+=(--skip-dir "$skip_dir")
    done
    ;;
  esac

  # Preserve native output in the orchestration log.
  # Parent --verbose controls whether it is streamed to the terminal.
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
  security-findings)
    SECURITY_FINDINGS=$((SECURITY_FINDINGS + 1))
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
  if [[ "$scanner" == trivy && "$TRIVY_MODE" == image ]]; then
    for image in "${IMAGES[@]}"; do
      run_job trivy "$image"
    done
  elif uses_targets "$scanner"; then
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
printf '  Jobs:                  %s\n' "$JOB_NUMBER"
printf '  Completed:             %s\n' "$SUCCESSES"
printf '  Malware-hit jobs:      %s\n' "$HITS"
printf '  Security-finding jobs: %s\n' "$SECURITY_FINDINGS"
printf '  Review required:       %s\n' "$REVIEWS"
printf '  Errors:                %s\n' "$ERRORS"
printf '  Summary:               %s\n' "$SUMMARY"

if [[ "$ERRORS" -gt 0 ]]; then
  exit 2
elif [[ "$HITS" -gt 0 || "$SECURITY_FINDINGS" -gt 0 ]]; then
  exit 1
elif [[ "$REVIEWS" -gt 0 ]]; then
  exit 3
else
  exit 0
fi
