#!/usr/bin/env bash
set -euo pipefail
umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

usage() {
  cat <<'EOF'
Usage: scan.sh [options]

Scan options:
  --test NAME           Run a selected test; repeatable. Default: chkrootkit's default test set
  --root DIR            Inspect an alternate root directory. Default: /
  --trusted-path  DIRS  Colon-separated trusted command directories
  --skip-nfs            Make supported checks skip NFS-mounted directories
  --expert              Enable additional native diagnostic output
  --work-dir      DIR   Run from a specified directory. Default: /

Output:
  --output-dir    DIR   Report parent directory. Default: /var/log/security-scans/chkrootkit
  --verbose             Stream output and save it to the report

Other:
  --list-tests          List available tests without scanning
  --dry-run             Print the plan without executing or writing files
  -h, --help            Show help

Notes:
  Scans require root.
  Full native output is saved even without --verbose.
  No automatic remediation, baseline updates, or allowlisting occurs.
  Package-specific helper layouts may require --work-dir.

Exit codes:
  0  Successful non-scan operation, such as listing tests or dry-run
  2  Native nonzero exit or wrapper/setup/report-writing failure
  3  Native scan returned zero; report still requires review

Exit code 3 does not mean malware was found.
Native scanner and report-writer statuses are saved in result.tsv.
EOF
}

DRY_RUN=0
VERBOSE=0
EXPERT=0
SKIP_NFS=0
LIST_TESTS=0
ROOT_DIR=/
WORK_DIR=/
TRUSTED_PATH=
OUTPUT_DIR=/var/log/security-scans/chkrootkit
TESTS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
  --test | --root | --trusted-path | --work-dir | --output-dir)
    chk_need_value "$@"

    case "$1" in
    --test)
      TESTS+=("$2")
      ;;
    --root)
      ROOT_DIR="$2"
      ;;
    --trusted-path)
      TRUSTED_PATH="$2"
      ;;
    --work-dir)
      WORK_DIR="$2"
      ;;
    --output-dir)
      OUTPUT_DIR="$2"
      ;;
    esac

    shift 2
    ;;

  --skip-nfs)
    SKIP_NFS=1
    shift
    ;;

  --expert)
    EXPERT=1
    shift
    ;;

  --verbose)
    VERBOSE=1
    shift
    ;;

  --list-tests)
    LIST_TESTS=1
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
    chk_die "Unknown option: $1"
    ;;
  esac
done

chk_require_linux
chk_prepare_path

ROOT_DIR="$(chk_absolute_path "$ROOT_DIR")"
WORK_DIR="$(chk_absolute_path "$WORK_DIR")"
OUTPUT_DIR="$(chk_absolute_path "$OUTPUT_DIR")"

[[ -d "$ROOT_DIR" ]] ||
  chk_die "Root directory does not exist: $ROOT_DIR"

[[ -d "$WORK_DIR" ]] ||
  chk_die "Working directory does not exist: $WORK_DIR"

## Permit simple test identifiers only, never option injection.
for test_name in "${TESTS[@]}"; do
  case "$test_name" in
  "" | -* | *[!a-zA-Z0-9_.-]*)
    chk_die "Invalid test name: $test_name"
    ;;
  esac
done

if [[ -n "$TRUSTED_PATH" ]]; then
  case "$TRUSTED_PATH" in
  :* | *: | *::*)
    chk_die "--trusted-path cannot contain empty directory entries."
    ;;
  esac

  TRUSTED_DIRS=()
  IFS=':' read -r -a TRUSTED_DIRS <<<"$TRUSTED_PATH"

  for trusted_dir in "${TRUSTED_DIRS[@]}"; do
    [[ "$trusted_dir" == /* && -d "$trusted_dir" ]] ||
      chk_die "Trusted command directory must exist and be absolute: $trusted_dir"
  done
fi

if [[ "$LIST_TESTS" -eq 1 ]]; then
  if [[ "$ROOT_DIR" != / ||
    "$SKIP_NFS" -eq 1 ||
    "$EXPERT" -eq 1 ||
    -n "$TRUSTED_PATH" ||
    ${#TESTS[@]} -gt 0 ]]; then
    chk_die "--list-tests cannot be combined with scan-selection options."
  fi
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  SCANNER=chkrootkit
else
  chk_have chkrootkit ||
    chk_die "chkrootkit not found. Run install.sh first."

  SCANNER="$(command -v chkrootkit)"
  SCANNER="$(chk_absolute_path "$SCANNER")"
fi

if [[ "$LIST_TESTS" -eq 1 ]]; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    chk_log "Working directory: $WORK_DIR"
    chk_print_command "$SCANNER" -l
    exit 0
  fi

  cd -- "$WORK_DIR"

  RC=0
  "$SCANNER" -l || RC=$?

  if [[ "$RC" -ne 0 ]]; then
    chk_die "Listing tests failed with native exit code $RC."
  fi

  exit 0
fi

CMD=("$SCANNER" -r "$ROOT_DIR")

if [[ "$SKIP_NFS" -eq 1 ]]; then
  CMD+=(-n)
fi

if [[ "$EXPERT" -eq 1 ]]; then
  CMD+=(-x)
fi

if [[ -n "$TRUSTED_PATH" ]]; then
  CMD+=(-p "$TRUSTED_PATH")
fi

CMD+=("${TESTS[@]}")

if [[ "$DRY_RUN" -eq 1 ]]; then
  chk_log "Working directory: $WORK_DIR"
  chk_log "Would create reports beneath: $OUTPUT_DIR"
  chk_print_command "${CMD[@]}"
  exit 0
fi

[[ "$EUID" -eq 0 ]] ||
  chk_die "Run scans as root: sudo ./scan.sh"

LOCK_DIR=/run/security-scans-chkrootkit.lock

if ! mkdir -m 0700 "$LOCK_DIR" 2>/dev/null; then
  chk_die "Suite lock exists: $LOCK_DIR. Check for another running scan."
fi

trap 'rmdir /run/security-scans-chkrootkit.lock 2>/dev/null || true' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

mkdir -p "$OUTPUT_DIR"
RUN_DIR="$(mktemp -d "$OUTPUT_DIR/scan.XXXXXXXX")"

chk_print_command "${CMD[@]}" >"$RUN_DIR/command.txt"

{
  printf 'started_utc=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf 'platform=%s\n' "$(uname -s)"
  printf 'architecture=%s\n' "$(uname -m)"
  printf 'scanner=%s\n' "$SCANNER"
  printf 'root=%s\n' "$ROOT_DIR"
  printf 'working_directory=%s\n' "$WORK_DIR"
  printf 'trusted_path=%s\n' "${TRUSTED_PATH:-native-default}"
} >"$RUN_DIR/metadata.txt"

## Version switches can have package-specific exit behavior.
VERSION_RC=0
"$SCANNER" -V >"$RUN_DIR/version.txt" 2>&1 || VERSION_RC=$?
printf 'version_command_exit_code=%s\n' "$VERSION_RC" \
  >>"$RUN_DIR/metadata.txt"

chk_log "Reports: $RUN_DIR"
chk_log "Working directory: $WORK_DIR"

cd -- "$WORK_DIR"

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

if [[ "$WRITER_RC" -ne 0 ]]; then
  STATUS=report-error
  EXIT_CODE=2
elif [[ "$NATIVE_RC" -ne 0 ]]; then
  STATUS=native-nonzero
  EXIT_CODE=2
else
  STATUS=review-required
  EXIT_CODE=3
fi

{
  printf 'tool\tstatus\tnative_exit_code\twriter_exit_code\n'
  printf 'chkrootkit\t%s\t%s\t%s\n' \
    "$STATUS" "$NATIVE_RC" "$WRITER_RC"
} >"$RUN_DIR/result.tsv"

chk_log "Result: $STATUS"
chk_log "Native exit code: $NATIVE_RC"
chk_log "Review: $RUN_DIR/output.log"

exit "$EXIT_CODE"
