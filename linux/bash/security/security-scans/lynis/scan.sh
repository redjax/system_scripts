#!/usr/bin/env bash
set -euo pipefail
umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

usage() {
  cat << 'EOF'
Usage: scan.sh [options]

Audit selection:
  --profile     FILE  Use an alternate Lynis profile
  --test        ID    Run a selected test; repeatable
  --category    NAME  Run tests from one category

Output:
  --output-dir  DIR   Report parent directory. Default: /var/log/security-scans/lynis
  --verbose           Stream native output while saving it

Executable:
  --lynis-bin   FILE  Explicit Lynis executable path. Useful when sudo cannot find Homebrew's executable

Other:
  --dry-run           Show the audit plan without running or writing files
  -h, --help          Show help

Behavior:
  - Audit the running host
  - Disable interactive pauses
  - Preserve full terminal output, native log, and structured report
  - Do not apply hardening changes

Scope:
  --test and --category cannot be combined.
  Test/category selection reduces coverage.
  Profiles may also change enabled checks and native exit behavior.

Exit codes:
  0  Successful dry run or help
  2  Native nonzero exit or wrapper/setup/report failure
  3  Native audit returned zero and produced reports; review required

Code 3 does not mean malware was found.
Native exit status is recorded in result.tsv.

Scans require root.
Use only trusted executables and profiles for privileged audits.
EOF
}

DRY_RUN=0
VERBOSE=0
PROFILE=
CATEGORY=
LYNIS_BIN=
OUTPUT_DIR=/var/log/security-scans/lynis
TESTS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile | --test | --category | --output-dir | --lynis-bin)
      lynis_need_value "$@"

      case "$1" in
        --profile)
          PROFILE="$2"
          ;;
        --test)
          TESTS+=("$2")
          ;;
        --category)
          CATEGORY="$2"
          ;;
        --output-dir)
          OUTPUT_DIR="$2"
          ;;
        --lynis-bin)
          LYNIS_BIN="$2"
          ;;
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
      lynis_die "Unknown option: $1"
      ;;
  esac
done

lynis_require_platform
lynis_prepare_path

if [[ -n "$CATEGORY" && ${#TESTS[@]} -gt 0 ]]; then
  lynis_die "Choose --test or --category, not both."
fi

for test_id in "${TESTS[@]}"; do
  [[ "$test_id" =~ ^[A-Z][A-Z0-9]*-[0-9]+$ ]] ||
    lynis_die "Invalid test ID: $test_id"
done

if [[ -n "$CATEGORY" ]]; then
  case "$CATEGORY" in
    -* | *[!a-zA-Z0-9_-]*)
      lynis_die "Invalid category name: $CATEGORY"
      ;;
  esac
fi

OUTPUT_DIR="$(lynis_absolute_path "$OUTPUT_DIR")"

if [[ -n "$PROFILE" ]]; then
  PROFILE="$(lynis_absolute_path "$PROFILE")"

  [[ -f "$PROFILE" && -r "$PROFILE" ]] ||
    lynis_die "Profile is missing or unreadable: $PROFILE"
fi

if [[ -n "$LYNIS_BIN" ]]; then
  LYNIS_BIN="$(lynis_absolute_path "$LYNIS_BIN")"

  [[ -f "$LYNIS_BIN" && -x "$LYNIS_BIN" ]] ||
    lynis_die "Lynis executable is missing or not executable: $LYNIS_BIN"
elif lynis_have lynis; then
  LYNIS_BIN="$(command -v lynis)"
  LYNIS_BIN="$(lynis_absolute_path "$LYNIS_BIN")"
elif [[ "$DRY_RUN" -eq 1 ]]; then
  LYNIS_BIN=lynis
else
  lynis_die "Lynis not found. Run install.sh or provide --lynis-bin."
fi

CMD=(
  "$LYNIS_BIN"
  audit system
  --quick
  --no-colors
)

if [[ -n "$PROFILE" ]]; then
  CMD+=(--profile "$PROFILE")
fi

if [[ ${#TESTS[@]} -gt 0 ]]; then
  TEST_SELECTION="${TESTS[*]}"
  CMD+=(--tests "$TEST_SELECTION")
fi

if [[ -n "$CATEGORY" ]]; then
  CMD+=(--tests-from-category "$CATEGORY")
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  lynis_log "Would create reports beneath: $OUTPUT_DIR"

  lynis_print_command \
    "${CMD[@]}" \
    --logfile '<run-directory>/lynis.log' \
    --report-file '<run-directory>/lynis-report.dat'

  exit 0
fi

[[ "$EUID" -eq 0 ]] ||
  lynis_die "Run audits as root: sudo ./scan.sh"

## No separate suite lock: Lynis remains responsible for its own
#  execution/locking behavior, including direct invocations.
mkdir -p "$OUTPUT_DIR"
RUN_DIR="$(mktemp -d "$OUTPUT_DIR/scan.XXXXXXXX")"

CMD+=(
  --logfile "$RUN_DIR/lynis.log"
  --report-file "$RUN_DIR/lynis-report.dat"
)

lynis_print_command "${CMD[@]}" > "$RUN_DIR/command.txt"

{
  printf 'started_utc=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf 'platform=%s\n' "$(uname -s)"
  printf 'architecture=%s\n' "$(uname -m)"
  printf 'executable=%s\n' "$LYNIS_BIN"
  printf 'profile=%s\n' "${PROFILE:-native-default}"
  printf 'category=%s\n' "${CATEGORY:-native-default}"
  printf 'tests=%s\n' "${TESTS[*]:-native-default}"
} > "$RUN_DIR/metadata.txt"

VERSION_RC=0
"$LYNIS_BIN" show version \
  > "$RUN_DIR/version.txt" 2>&1 || VERSION_RC=$?

printf 'version_command_exit_code=%s\n' "$VERSION_RC" \
  >> "$RUN_DIR/metadata.txt"

lynis_log "Reports: $RUN_DIR"

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
  : > "$RUN_DIR/output.log"
  "${CMD[@]}" > "$RUN_DIR/output.log" 2>&1 || NATIVE_RC=$?
fi

REPORT="$RUN_DIR/lynis-report.dat"
WARNINGS=unknown
SUGGESTIONS=unknown

if [[ -s "$REPORT" ]]; then
  ## Count structured report records, not terminal-output words.
  WARNINGS="$(
    awk 'index($0, "warning[]=") == 1 { n++ }
         END { print n+0 }' "$REPORT"
  )"

  SUGGESTIONS="$(
    awk 'index($0, "suggestion[]=") == 1 { n++ }
         END { print n+0 }' "$REPORT"
  )"

  awk '
    index($0, "warning[]=") == 1 ||
    index($0, "suggestion[]=") == 1
  ' "$REPORT" > "$RUN_DIR/findings.txt"
fi

if [[ "$WRITER_RC" -ne 0 ]]; then
  STATUS=report-error
  EXIT_CODE=2
elif [[ "$NATIVE_RC" -ne 0 ]]; then
  STATUS=native-nonzero
  EXIT_CODE=2
elif [[ ! -s "$REPORT" || ! -s "$RUN_DIR/lynis.log" ]]; then
  STATUS=missing-native-report
  EXIT_CODE=2
else
  STATUS=review-required
  EXIT_CODE=3
fi

{
  printf 'tool\tstatus\tnative_exit_code\twriter_exit_code\twarnings\tsuggestions\n'
  printf 'lynis\t%s\t%s\t%s\t%s\t%s\n' \
    "$STATUS" "$NATIVE_RC" "$WRITER_RC" "$WARNINGS" "$SUGGESTIONS"
} > "$RUN_DIR/result.tsv"

lynis_log "Result: $STATUS"
lynis_log "Native exit code: $NATIVE_RC"
lynis_log "Warnings: $WARNINGS"
lynis_log "Suggestions: $SUGGESTIONS"
lynis_log "Terminal output: $RUN_DIR/output.log"

if [[ -f "$RUN_DIR/findings.txt" ]]; then
  lynis_log "Extracted findings: $RUN_DIR/findings.txt"
fi

exit "$EXIT_CODE"
