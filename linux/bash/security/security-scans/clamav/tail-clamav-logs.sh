#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

usage() {
  cat <<'EOF'
Usage:
  tail-clamav-logs.sh --log-file FILE [--lines N]
  tail-clamav-logs.sh --journal-unit UNIT [--lines N]

Options:
  -l, --log-file FILE    Follow an existing scan or service log
      --journal-unit U  Follow an explicitly selected systemd unit
  -n, --lines N          Initial lines to display (default: 50)
  -h, --help             Show help

Examples:
  ./tail-clamav-logs.sh --log-file ./clamav-reports/run.ABC/output.log
  ./tail-clamav-logs.sh --journal-unit clamav-freshclam.service
EOF
}

LOG_FILE=
JOURNAL_UNIT=
LINES=50

while [[ $# -gt 0 ]]; do
  case "$1" in
  -l | --log-file | --journal-unit | -n | --lines)
    clam_need_value "$@"

    case "$1" in
    -l | --log-file) LOG_FILE="$2" ;;
    --journal-unit) JOURNAL_UNIT="$2" ;;
    -n | --lines) LINES="$2" ;;
    esac

    shift 2
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

[[ "$LINES" =~ ^[0-9]+$ ]] ||
  clam_die "--lines must be a nonnegative integer."

if [[ -n "$LOG_FILE" && -n "$JOURNAL_UNIT" ]]; then
  clam_die "Choose --log-file or --journal-unit, not both."
fi

if [[ -n "$JOURNAL_UNIT" ]]; then
  clam_have journalctl ||
    clam_die "journalctl is unavailable."

  exec journalctl \
    --unit="$JOURNAL_UNIT" \
    --lines="$LINES" \
    --follow
fi

[[ -n "$LOG_FILE" ]] ||
  clam_die "Specify --log-file or --journal-unit."

LOG_FILE="$(clam_absolute_path "$LOG_FILE")"

[[ -f "$LOG_FILE" && -r "$LOG_FILE" ]] ||
  clam_die "Log file is missing or unreadable: $LOG_FILE"

exec tail -n "$LINES" -f "$LOG_FILE"
