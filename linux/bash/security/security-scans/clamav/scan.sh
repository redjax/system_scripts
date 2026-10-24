#!/usr/bin/env bash
set -euo pipefail
umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

usage() {
  cat << 'EOF'
Usage: scan.sh [options]

Targets:
  -t, --target PATH       Target to scan; repeatable
      --path PATH         Alias for --target
                          Default: current directory

Scan options:
  -r, --recursive        Scan recursively (default)
      --no-recursive     Disable recursive directory scanning
  -e, --exclude REGEX    Exclude matching files; repeatable
      --exclude-dir REGEX
                         Exclude matching directories; repeatable
      --one-file-system  Do not cross filesystem boundaries
      --max-filesize N   Per-file limit, e.g. 50M
      --max-scansize N   Per-container scan limit, e.g. 200M
      --database DIR    Signature directory

Output:
  -i, --infected-only    Print infected files and summary (default)
      --all-files       Also print clean-file results
      --no-summary      Disable the final ClamAV summary
  -v, --verbose         Enable ClamAV verbose output
      --output-dir DIR  Report parent directory
                        Default: ./clamav-reports

Other:
      --dry-run         Print command without running or writing files
  -h, --help            Show help

Exclusions are regular expressions, not shell globs.

Exit codes:
  0  No malware detected by the completed scan
  1  Malware detected
  2  Scanner, argument, dependency, or report-writing error

No files are deleted or quarantined.
Signatures are not updated automatically.
EOF
}

DRY_RUN=0
RECURSIVE=1
INFECTED_ONLY=1
NO_SUMMARY=0
VERBOSE=0
ONE_FILE_SYSTEM=0
DATABASE="$(clam_default_database)"
OUTPUT_DIR="$PWD/clamav-reports"
MAX_FILESIZE=
MAX_SCANSIZE=
TARGETS=()
EXCLUDES=()
EXCLUDE_DIRS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -t | --target | --path | -e | --exclude | --exclude-dir | --database | \
      --output-dir | --max-filesize | --max-scansize)
      clam_need_value "$@"

      case "$1" in
        -t | --target | --path) TARGETS+=("$2") ;;
        -e | --exclude) EXCLUDES+=("$2") ;;
        --exclude-dir) EXCLUDE_DIRS+=("$2") ;;
        --database) DATABASE="$2" ;;
        --output-dir) OUTPUT_DIR="$2" ;;
        --max-filesize) MAX_FILESIZE="$2" ;;
        --max-scansize) MAX_SCANSIZE="$2" ;;
      esac

      shift 2
      ;;
    -r | --recursive)
      RECURSIVE=1
      shift
      ;;
    --no-recursive)
      RECURSIVE=0
      shift
      ;;
    -i | --infected-only)
      INFECTED_ONLY=1
      shift
      ;;
    --all-files)
      INFECTED_ONLY=0
      shift
      ;;
    --no-summary)
      NO_SUMMARY=1
      shift
      ;;
    --one-file-system)
      ONE_FILE_SYSTEM=1
      shift
      ;;
    -v | --verbose)
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
      clam_die "Unknown option: $1"
      ;;
  esac
done

for size in "$MAX_FILESIZE" "$MAX_SCANSIZE"; do
  if [[ -n "$size" && ! "$size" =~ ^[1-9][0-9]*[KkMm]?$ ]]; then
    clam_die "Invalid size: $size. Use bytes or a K/M suffix."
  fi
done

if [[ ${#TARGETS[@]} -eq 0 ]]; then
  TARGETS=("$PWD")
fi

for ((i = 0; i < ${#TARGETS[@]}; i++)); do
  [[ -e "${TARGETS[$i]}" ]] ||
    clam_die "Target does not exist: ${TARGETS[$i]}"

  TARGETS[$i]="$(clam_absolute_path "${TARGETS[$i]}")"
done

DATABASE="$(clam_absolute_path "$DATABASE")"
OUTPUT_DIR="$(clam_absolute_path "$OUTPUT_DIR")"

CMD=(
  clamscan
  --stdout
  "--database=$DATABASE"
  --follow-dir-symlinks=0
  --follow-file-symlinks=0
)

if [[ "$RECURSIVE" -eq 1 ]]; then
  CMD+=(--recursive)
fi

if [[ "$INFECTED_ONLY" -eq 1 ]]; then
  CMD+=(--infected)
fi

if [[ "$NO_SUMMARY" -eq 1 ]]; then
  CMD+=(--no-summary)
fi

if [[ "$VERBOSE" -eq 1 ]]; then
  CMD+=(--verbose)
fi

if [[ "$ONE_FILE_SYSTEM" -eq 1 ]]; then
  CMD+=(--cross-fs=no)
fi

if [[ -n "$MAX_FILESIZE" ]]; then
  CMD+=("--max-filesize=$MAX_FILESIZE")
fi

if [[ -n "$MAX_SCANSIZE" ]]; then
  CMD+=("--max-scansize=$MAX_SCANSIZE")
fi

for regex in "${EXCLUDES[@]}"; do
  CMD+=("--exclude=$regex")
done

for regex in "${EXCLUDE_DIRS[@]}"; do
  CMD+=("--exclude-dir=$regex")
done

if [[ "$DRY_RUN" -eq 1 ]]; then
  clam_log "Reports would be written beneath: $OUTPUT_DIR"
  clam_log "The generated run directory would be excluded from scanning."
  clam_print_command "${CMD[@]}" "${TARGETS[@]}"
  exit 0
fi

clam_have clamscan ||
  clam_die "clamscan not found. Run install.sh first."

[[ -d "$DATABASE" && -r "$DATABASE" ]] ||
  clam_die "Database unavailable: $DATABASE. Run freshclam-update.sh."

mkdir -p "$OUTPUT_DIR"
RUN_DIR="$(mktemp -d "$OUTPUT_DIR/run.XXXXXXXX")"
REPORT="$RUN_DIR/output.log"

# Escape the run path for use as an extended regular expression.
RUN_REGEX="$(
  printf '%s\n' "$RUN_DIR" |
    sed 's/[][\\.^$*+?(){}|]/\\&/g'
)"

# Avoid scanning a report while this scan is writing it.
CMD+=("--exclude-dir=^${RUN_REGEX}(/|$)")
CMD+=("${TARGETS[@]}")

clam_print_command "${CMD[@]}" > "$RUN_DIR/command.txt"

{
  printf 'started_utc=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf 'platform=%s\n' "$(uname -s)"
  printf 'architecture=%s\n' "$(uname -m)"
  printf 'database=%s\n' "$DATABASE"
  clamscan --version
} > "$RUN_DIR/metadata.txt"

clam_log "Report: $REPORT"

# Capture both native scanner and report-writer statuses.
set +e
"${CMD[@]}" 2>&1 | tee "$REPORT"
PIPE_CODES=("${PIPESTATUS[@]}")
set -e

SCAN_RC="${PIPE_CODES[0]}"
TEE_RC="${PIPE_CODES[1]}"

if [[ "$TEE_RC" -ne 0 ]]; then
  STATUS=report-error
  EXIT_CODE=2
else
  case "$SCAN_RC" in
    0)
      STATUS=no-detection
      EXIT_CODE=0
      ;;
    1)
      STATUS=malware-detected
      EXIT_CODE=1
      ;;
    *)
      STATUS=scan-error
      EXIT_CODE=2
      ;;
  esac
fi

{
  printf 'tool\tstatus\tnative_exit_code\treport_exit_code\n'
  printf 'clamav\t%s\t%s\t%s\n' "$STATUS" "$SCAN_RC" "$TEE_RC"
} > "$RUN_DIR/result.tsv"

clam_log "Result: $STATUS"
clam_log "Native scanner exit code: $SCAN_RC"
clam_log "Run directory: $RUN_DIR"

exit "$EXIT_CODE"
