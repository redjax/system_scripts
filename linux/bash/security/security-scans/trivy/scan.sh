#!/usr/bin/env bash
set -euo pipefail
umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

usage() {
  cat <<'EOF'
Usage:
  scan.sh --mode filesystem --target DIR [options]
  scan.sh --mode rootfs --target DIR [options]
  scan.sh --mode image --image REF [options]

Scope:
  --mode            MODE      'filesystem', 'rootfs', or 'image'. Default: filesystem
  --target          DIR       Existing directory for filesystem/rootfs scans
  --image           REF       Image reference for image scans

Policy:
  --scanners        LIST      Comma-separated: vuln,secret,misconfig. Default: vuln
  --severity        LIST      UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL. Default: all severities
  --ignore-unfixed            Filter vulnerabilities without a known fix
  --ignorefile      FILE      Explicit Trivy ignore file
  --skip-dir        PATH      Skip directory/pattern; repeatable
  --config          FILE      Explicit Trivy configuration

Execution:
  --trivy-bin       FILE      Explicit executable path
  --cache-dir       DIR       Explicit cache directory
  --output-dir      DIR       Report parent directory. Default: ./trivy-reports
  --verbose                   Stream native scan logs and print the saved table
  --dry-run                   Print plan without executing or writing files
  --timeout         DURATION  Scan timeout, e.g. 30s, 15m, 1h. Default: 15m
  -h, --help                  Show help

Defaults:
  - No implicit main config or ignore file is loaded by this wrapper.
  - Other native settings, environment variables, and scanner-specific
  files can still influence Trivy.
  - Vulnerability database downloads/refreshes occur as Trivy requires.

Rootfs mode is enabled only on Linux by this adapter.
Filesystem/image scans do not inherently require root.

Exit codes:
  0  No selected findings at the configured severities
  1  Selected findings detected
  2  Execution, conversion, dependency, or report-writing error

No remediation is performed.
EOF
}

MODE=filesystem
TARGET=
IMAGE=
SCANNERS=vuln
SEVERITY=UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL
IGNORE_UNFIXED=0
IGNOREFILE=
CONFIG=
TRIVY_BIN=
CACHE_DIR=
OUTPUT_DIR="$PWD/trivy-reports"
VERBOSE=0
DRY_RUN=0
SKIP_DIRS=()
TIMEOUT=15m

while [[ $# -gt 0 ]]; do
  case "$1" in
  --mode | --target | --image | --scanners | --severity | \
    --ignorefile | --config | --trivy-bin | --cache-dir | \
    --output-dir | --skip-dir | --timeout)
    tv_need_value "$@"

    case "$1" in
    --mode) MODE="$2" ;;
    --target) TARGET="$2" ;;
    --image) IMAGE="$2" ;;
    --scanners) SCANNERS="$2" ;;
    --severity) SEVERITY="$2" ;;
    --ignorefile) IGNOREFILE="$2" ;;
    --config) CONFIG="$2" ;;
    --trivy-bin) TRIVY_BIN="$2" ;;
    --cache-dir) CACHE_DIR="$2" ;;
    --output-dir) OUTPUT_DIR="$2" ;;
    --skip-dir) SKIP_DIRS+=("$2") ;;
    --timeout) TIMEOUT="$2" ;;
    esac

    shift 2
    ;;
  --ignore-unfixed)
    IGNORE_UNFIXED=1
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
    tv_die "Unknown option: $1"
    ;;
  esac
done

tv_require_platform

case "$MODE" in
filesystem | rootfs)
  [[ -n "$TARGET" && -z "$IMAGE" ]] ||
    tv_die "$MODE requires --target and does not accept --image."

  TARGET="$(tv_absolute_path "$TARGET")"
  [[ -d "$TARGET" ]] || tv_die "Target directory does not exist: $TARGET"

  if [[ "$MODE" == rootfs && "$(uname -s)" != Linux ]]; then
    tv_die "This adapter enables rootfs mode on Linux only."
  fi

  SCAN_TARGET="$TARGET"
  ;;
image)
  [[ -n "$IMAGE" && -z "$TARGET" ]] ||
    tv_die "Image mode requires --image and does not accept --target."

  [[ "$IMAGE" != -* ]] || tv_die "Invalid image reference."
  SCAN_TARGET="$IMAGE"
  ;;
*)
  tv_die "Unknown mode: $MODE"
  ;;
esac

validate_list() {
  local list="$1"
  local kind="$2"
  local item
  local -a items=()

  case "$list" in
  "" | ,* | *, | *,,*) tv_die "Invalid $kind list: $list" ;;
  esac

  IFS=',' read -r -a items <<<"$list"

  for item in "${items[@]}"; do
    case "$kind:$item" in
    scanners:vuln | scanners:secret | scanners:misconfig | \
      severity:UNKNOWN | severity:LOW | severity:MEDIUM | \
      severity:HIGH | severity:CRITICAL) ;;
    *)
      tv_die "Unsupported $kind value: $item"
      ;;
    esac
  done
}

validate_list "$SCANNERS" scanners
validate_list "$SEVERITY" severity

## Accept simple positive durations such as 30s, 15m, or 1h.
[[ "$TIMEOUT" =~ ^[1-9][0-9]*[smh]$ ]] ||
  tv_die "--timeout must be a positive duration such as 30s, 15m, or 1h."

for file_option in "$CONFIG" "$IGNOREFILE"; do
  [[ -z "$file_option" || -f "$file_option" && -r "$file_option" ]] ||
    tv_die "Configuration/ignore file is missing or unreadable: $file_option"
done

if [[ -n "$CONFIG" ]]; then
  CONFIG="$(tv_absolute_path "$CONFIG")"
fi

if [[ -n "$IGNOREFILE" ]]; then
  IGNOREFILE="$(tv_absolute_path "$IGNOREFILE")"
else
  IGNOREFILE=/dev/null
fi

if [[ -n "$CACHE_DIR" ]]; then
  CACHE_DIR="$(tv_absolute_path "$CACHE_DIR")"
fi

OUTPUT_DIR="$(tv_absolute_path "$OUTPUT_DIR")"

if [[ -n "$TRIVY_BIN" ]]; then
  TRIVY_BIN="$(tv_absolute_path "$TRIVY_BIN")"
  [[ -f "$TRIVY_BIN" && -x "$TRIVY_BIN" ]] ||
    tv_die "Invalid executable: $TRIVY_BIN"
elif tv_have trivy; then
  TRIVY_BIN="$(tv_absolute_path "$(command -v trivy)")"
elif [[ -x /usr/local/bin/trivy ]]; then
  TRIVY_BIN=/usr/local/bin/trivy
elif [[ "$DRY_RUN" -eq 1 ]]; then
  TRIVY_BIN=trivy
else
  tv_die "Trivy not found. Run install.sh or provide --trivy-bin."
fi

RUN_DIR=

if [[ "$DRY_RUN" -eq 1 ]]; then
  RUN_DIR="$OUTPUT_DIR/<unique-run>"
  CONFIG_PATH="${CONFIG:-<generated-empty-config>}"
else
  mkdir -p "$OUTPUT_DIR"
  RUN_DIR="$(mktemp -d "$OUTPUT_DIR/scan.XXXXXXXX")"

  if [[ -n "$CONFIG" ]]; then
    CONFIG_PATH="$CONFIG"
  else
    CONFIG_PATH="$RUN_DIR/empty-config.yaml"
    printf '{}\n' >"$CONFIG_PATH"
  fi
fi

CMD=(
  "$TRIVY_BIN"
  "$MODE"
  --config "$CONFIG_PATH"
  --scanners "$SCANNERS"
  --severity "$SEVERITY"
  --ignorefile "$IGNOREFILE"
  --exit-code 10
  --format json
  --output "$RUN_DIR/report.json"
  --no-progress
  --timeout "$TIMEOUT"
)

if [[ "$IGNORE_UNFIXED" -eq 1 ]]; then
  CMD+=(--ignore-unfixed)
fi

if [[ -n "$CACHE_DIR" ]]; then
  CMD+=(--cache-dir "$CACHE_DIR")
fi

for skip_dir in "${SKIP_DIRS[@]}"; do
  CMD+=(--skip-dirs "$skip_dir")
done

CMD+=("$SCAN_TARGET")

if [[ "$DRY_RUN" -eq 1 ]]; then
  tv_print_command "${CMD[@]}"
  tv_log "Would convert saved JSON into report.txt."
  exit 0
fi

tv_print_command "${CMD[@]}" >"$RUN_DIR/command.txt"

{
  printf 'started_utc=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf 'mode=%s\n' "$MODE"
  printf 'target=%s\n' "$SCAN_TARGET"
  printf 'scanners=%s\n' "$SCANNERS"
  printf 'severity=%s\n' "$SEVERITY"
  printf 'ignore_unfixed=%s\n' "$IGNORE_UNFIXED"
  printf 'timeout=%s\n' "$TIMEOUT"
} >"$RUN_DIR/metadata.txt"

"$TRIVY_BIN" --version >"$RUN_DIR/version.txt" 2>&1

tv_log "Mode: $MODE"
tv_log "Reports: $RUN_DIR"

NATIVE_RC=0
WRITER_RC=0

if [[ "$VERBOSE" -eq 1 ]]; then
  set +e
  "${CMD[@]}" 2>&1 | tee "$RUN_DIR/output.log"
  PIPE_CODES=("${PIPESTATUS[@]}")
  set -e

  NATIVE_RC="${PIPE_CODES[0]}"
  WRITER_RC="${PIPE_CODES[1]}"
else
  : >"$RUN_DIR/output.log"
  "${CMD[@]}" >"$RUN_DIR/output.log" 2>&1 || NATIVE_RC=$?
fi

CONVERT_RC=0

if [[ "$NATIVE_RC" -eq 0 || "$NATIVE_RC" -eq 10 ]] &&
  [[ -s "$RUN_DIR/report.json" ]]; then
  "$TRIVY_BIN" convert \
    --config "$CONFIG_PATH" \
    --exit-code 0 \
    --severity "$SEVERITY" \
    --ignorefile /dev/null \
    --format table \
    --output "$RUN_DIR/report.txt" \
    "$RUN_DIR/report.json" \
    >"$RUN_DIR/convert.log" 2>&1 || CONVERT_RC=$?
else
  CONVERT_RC=1
fi

if [[ "$WRITER_RC" -ne 0 || "$CONVERT_RC" -ne 0 ]]; then
  STATUS=report-error
  EXIT_CODE=2
else
  case "$NATIVE_RC" in
  0)
    STATUS=no-selected-findings
    EXIT_CODE=0
    ;;
  10)
    STATUS=findings-detected
    EXIT_CODE=1
    ;;
  *)
    STATUS=scan-error
    EXIT_CODE=2
    ;;
  esac
fi

# Preserve scan-error classification when the native scan itself failed.
if [[ "$NATIVE_RC" -ne 0 && "$NATIVE_RC" -ne 10 ]]; then
  STATUS=scan-error
  EXIT_CODE=2
fi

{
  printf 'tool\tstatus\tnative_exit_code\twriter_exit_code\tconvert_exit_code\n'
  printf 'trivy\t%s\t%s\t%s\t%s\n' \
    "$STATUS" "$NATIVE_RC" "$WRITER_RC" "$CONVERT_RC"
} >"$RUN_DIR/result.tsv"

if [[ "$VERBOSE" -eq 1 && -f "$RUN_DIR/report.txt" ]]; then
  cat "$RUN_DIR/report.txt"
fi

tv_log "Result: $STATUS"
tv_log "Native exit code: $NATIVE_RC"
tv_log "JSON: $RUN_DIR/report.json"
tv_log "Table: $RUN_DIR/report.txt"

exit "$EXIT_CODE"
