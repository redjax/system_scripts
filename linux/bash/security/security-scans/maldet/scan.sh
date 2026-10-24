#!/usr/bin/env bash
set -euo pipefail
umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

usage() {
  cat << 'EOF'
Usage: scan.sh --target PATH [options]

Target:
  --target           PATH    One existing literal directory or file. Required; no wildcard or comma-list targets

Scan options:
  --recent-days      N       Scan files changed within the last N days.
  --engine           ENGINE  'native' or 'clamav'. Default: native
  --max-filesize-kb  N       Maximum file size in KiB. Default: 2048
  --max-depth        N       Maximum directory traversal depth. Default: 30

Output:
  --output-dir       DIR     Report parent directory. Default: /var/log/security-scans/maldet
  --verbose                  Stream output while saving it.

Other:
  --dry-run                  Print the plan without executing or writing files
  -h, --help                 Show help

Exit codes:
  0  Native scan reported success with no malware hits
  1  Native scan reported malware hits
  2  Native scan error or wrapper/report-writing failure

Run scans as root.
This wrapper does not control independent scheduled jobs or monitors.
EOF
}

TARGET=
RECENT_DAYS=
ENGINE=native
MAX_FILESIZE_KB=2048
MAX_DEPTH=30
OUTPUT_DIR=/var/log/security-scans/maldet
VERBOSE=0
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target | --recent-days | --engine | --max-filesize-kb | \
      --max-depth | --output-dir)
      md_need_value "$@"

      case "$1" in
        --target) TARGET="$2" ;;
        --recent-days) RECENT_DAYS="$2" ;;
        --engine) ENGINE="$2" ;;
        --max-filesize-kb) MAX_FILESIZE_KB="$2" ;;
        --max-depth) MAX_DEPTH="$2" ;;
        --output-dir) OUTPUT_DIR="$2" ;;
      esac

      shift 2
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
      md_die "Unknown option: $1"
      ;;
  esac
done

md_require_linux
md_prepare_path
unset LMD_BASEDIR

[[ -n "$TARGET" ]] ||
  md_die "--target is required."

TARGET="$(md_absolute_path "$TARGET")"
OUTPUT_DIR="$(md_absolute_path "$OUTPUT_DIR")"

[[ -f "$TARGET" || -d "$TARGET" ]] ||
  md_die "Target must be an existing regular file or directory: $TARGET"

case "$TARGET" in
  *'*'* | *'?'* | *'['* | *','* | *$'\n'* | *$'\r'*)
    md_die "Target contains unsupported wildcard, list, or newline characters."
    ;;
esac

case "$ENGINE" in
  native)
    CLAMAV_ENABLED=0
    ;;
  clamav)
    CLAMAV_ENABLED=1
    ;;
  *)
    md_die "--engine must be native or clamav."
    ;;
esac

for number in "$MAX_FILESIZE_KB" "$MAX_DEPTH"; do
  [[ "$number" =~ ^[1-9][0-9]*$ ]] ||
    md_die "Size and depth must be positive integers."
done

if [[ -n "$RECENT_DAYS" ]]; then
  [[ "$RECENT_DAYS" =~ ^[1-9][0-9]*$ ]] ||
    md_die "--recent-days must be a positive integer."
fi

## No arbitrary user-provided runtime overrides are accepted.
OVERRIDES="quarantine_hits=0"
OVERRIDES+=",quarantine_clean=0"
OVERRIDES+=",quarantine_suspend_user=0"
OVERRIDES+=",quarantine_on_error=0"
OVERRIDES+=",email_alert=0"
OVERRIDES+=",email_panel_user_alerts=0"
OVERRIDES+=",slack_alert=0"
OVERRIDES+=",telegram_alert=0"
OVERRIDES+=",discord_alert=0"
OVERRIDES+=",scan_ignore_root=0"
OVERRIDES+=",scan_clamscan=$CLAMAV_ENABLED"
OVERRIDES+=",scan_max_filesize=${MAX_FILESIZE_KB}k"
OVERRIDES+=",scan_max_depth=$MAX_DEPTH"

CMD=(maldet --config-option "$OVERRIDES")

if [[ -n "$RECENT_DAYS" ]]; then
  CMD+=(--scan-recent "$TARGET" "$RECENT_DAYS")
else
  CMD+=(--scan-all "$TARGET")
fi

md_log "Target: $TARGET"
md_log "Engine requested: $ENGINE"
md_log "Maximum file size: ${MAX_FILESIZE_KB} KiB"
md_log "Maximum depth: $MAX_DEPTH"

if [[ "$DRY_RUN" -eq 1 ]]; then
  md_log "Would save reports beneath: $OUTPUT_DIR"
  md_print_command "${CMD[@]}"
  exit 0
fi

md_require_root
md_find_binary
md_check_config_safety
md_require_v2

if [[ "$ENGINE" == clamav ]]; then
  if ! md_have clamscan && ! md_have clamdscan; then
    md_die "ClamAV engine requested, but no ClamAV scanner is on PATH."
  fi
fi

CMD[0]="$MALDET_BIN"

mkdir -p "$OUTPUT_DIR"
RUN_DIR="$(mktemp -d "$OUTPUT_DIR/scan.XXXXXXXX")"

md_print_command "${CMD[@]}" > "$RUN_DIR/command.txt"
printf '%s\n' "$MALDET_VERSION_OUTPUT" > "$RUN_DIR/version.txt"

{
  printf 'started_utc=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf 'target=%s\n' "$TARGET"
  printf 'requested_engine=%s\n' "$ENGINE"
  printf 'max_filesize_kib=%s\n' "$MAX_FILESIZE_KB"
  printf 'max_depth=%s\n' "$MAX_DEPTH"
  printf 'recent_days=%s\n' "${RECENT_DAYS:-all}"
} > "$RUN_DIR/metadata.txt"

md_log "Reports: $RUN_DIR"

md_capture "$RUN_DIR/output.log" "$VERBOSE" "${CMD[@]}"

if [[ "$MD_WRITER_RC" -ne 0 ]]; then
  STATUS=report-error
  EXIT_CODE=2
else
  case "$MD_NATIVE_RC" in
    0)
      STATUS=no-hits-reported
      EXIT_CODE=0
      ;;
    2)
      STATUS=malware-hits
      EXIT_CODE=1
      ;;
    *)
      STATUS=scan-error
      EXIT_CODE=2
      ;;
  esac
fi

{
  printf 'tool\tstatus\tnative_exit_code\twriter_exit_code\n'
  printf 'maldet\t%s\t%s\t%s\n' \
    "$STATUS" "$MD_NATIVE_RC" "$MD_WRITER_RC"
} > "$RUN_DIR/result.tsv"

md_log "Result: $STATUS"
md_log "Native exit code: $MD_NATIVE_RC"
md_log "Output: $RUN_DIR/output.log"
md_log "Use the SCANID printed by Maldet to request its native report."
md_log "Review scanned-file counts and actual engine selection."

exit "$EXIT_CODE"
