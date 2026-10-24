#!/usr/bin/env bash
set -euo pipefail
umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

usage() {
  cat <<'EOF'
Usage: update.sh [options]

Options:
  --output-dir  DIR  Report parent directory. Default: /var/log/security-scans/maldet
  --verbose          Stream output while saving it
  --dry-run          Show the command without executing
  -h, --help         Show help

Updates signatures only, not the installed Maldet program.

Upstream signature updates can refresh integrated ClamAV signatures.

Exit codes:
  0  Native updater returned success
  2  Update, dependency, or report-writing failure

Run as root.
EOF
}

OUTPUT_DIR=/var/log/security-scans/maldet
VERBOSE=0
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
  --output-dir)
    md_need_value "$@"
    OUTPUT_DIR="$2"
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

OUTPUT_DIR="$(md_absolute_path "$OUTPUT_DIR")"

if [[ "$DRY_RUN" -eq 1 ]]; then
  md_log "Would save reports beneath: $OUTPUT_DIR"
  md_print_command maldet --update-sigs
  exit 0
fi

md_require_root
md_find_binary
md_check_config_safety
md_require_v2

mkdir -p "$OUTPUT_DIR"
RUN_DIR="$(mktemp -d "$OUTPUT_DIR/update.XXXXXXXX")"

CMD=("$MALDET_BIN" --update-sigs)

md_print_command "${CMD[@]}" >"$RUN_DIR/command.txt"
printf '%s\n' "$MALDET_VERSION_OUTPUT" >"$RUN_DIR/version.txt"

md_log "Reports: $RUN_DIR"

md_capture "$RUN_DIR/output.log" "$VERBOSE" "${CMD[@]}"

STATUS=success
EXIT_CODE=0

if [[ "$MD_NATIVE_RC" -ne 0 || "$MD_WRITER_RC" -ne 0 ]]; then
  STATUS=update-error
  EXIT_CODE=2
fi

{
  printf 'tool\tstatus\tnative_exit_code\twriter_exit_code\n'
  printf 'maldet\t%s\t%s\t%s\n' \
    "$STATUS" "$MD_NATIVE_RC" "$MD_WRITER_RC"
} >"$RUN_DIR/result.tsv"

md_log "Result: $STATUS"
md_log "Native exit code: $MD_NATIVE_RC"
md_log "Output: $RUN_DIR/output.log"

exit "$EXIT_CODE"
