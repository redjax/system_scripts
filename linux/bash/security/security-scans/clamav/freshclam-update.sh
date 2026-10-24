#!/usr/bin/env bash
set -euo pipefail
umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

usage() {
  cat <<'EOF'
Usage: freshclam-update.sh [options]

Options:
  --database DIR  Directory for the script-managed signature database
  -v, --verbose   Enable FreshClam verbose output
  --dry-run       Show the update plan without making changes
  -h, --help      Show help

Default database:
  ${XDG_CACHE_HOME:-$HOME/.cache}/security-scans/clamav/db

Run as the intended database owner.
Do not use a directory concurrently maintained by another updater.

Exit codes:
  0  Update completed
  2  Configuration, dependency, or update failure

FreshClam's native failure code is printed on failure.
EOF
}

DRY_RUN=0
VERBOSE=0
DATABASE="$(clam_default_database)"

while [[ $# -gt 0 ]]; do
  case "$1" in
  --database)
    clam_need_value "$@"
    DATABASE="$2"
    shift 2
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

DATABASE="$(clam_absolute_path "$DATABASE")"

## The path is embedded in a quoted FreshClam configuration directive.
case "$DATABASE" in
*$'\n'* | *$'\r'* | *'"'* | *'\'*)
  clam_die "Database path contains unsupported configuration characters."
  ;;
esac

if [[ "$DRY_RUN" -eq 1 ]]; then
  clam_log "Would create database directory: $DATABASE"
  clam_log "Would create a temporary FreshClam configuration."
  clam_print_command freshclam \
    "--config-file=<temporary-config>" \
    "--datadir=$DATABASE"
  exit 0
fi

clam_have freshclam ||
  clam_die "freshclam not found. Run install.sh first."

mkdir -p "$DATABASE"
[[ -w "$DATABASE" ]] ||
  clam_die "Database directory is not writable: $DATABASE"

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/clamav-update.XXXXXXXX")"
trap 'rm -rf -- "$WORK_DIR"' EXIT

CONFIG="$WORK_DIR/freshclam.conf"

{
  printf 'DatabaseDirectory "%s"\n' "$DATABASE"
  printf 'DatabaseOwner %s\n' "$(id -un)"
  printf 'DatabaseMirror database.clamav.net\n'
} >"$CONFIG"

CMD=(freshclam "--config-file=$CONFIG")

if [[ "$VERBOSE" -eq 1 ]]; then
  CMD+=(--verbose)
fi

clam_log "Updating signatures in: $DATABASE"

RC=0
"${CMD[@]}" || RC=$?

if [[ "$RC" -ne 0 ]]; then
  clam_die "FreshClam failed with native exit code $RC."
fi

clam_log "Definitions updated."
