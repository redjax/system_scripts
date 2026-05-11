#!/usr/bin/env bash
set -euo pipefail

##########################################
# This script is run multiple times in   #
# parallel to mirror repositories,       #
# orchestrated by parallel-mirror.sh     #
#                                        #
# It is not intended to be run directly. #
##########################################

URL="$1"
DEST="$2"
AUTH_MODE="${3:-none}"
STATE_DIR="${4:-./state}"
LOG_DIR="${5:-./logs}"

NAME="$(basename "$DEST")"

mkdir -p "$LOG_DIR" "$STATE_DIR"/{success,failed,retries}

LOG_FILE="$LOG_DIR/$NAME.log"

function log() {
  echo "[$(date '+%F %T')] $*" | tee -a "$LOG_FILE"
}

function mark_success() {
  echo "$(date '+%s')" > "$STATE_DIR/success/$NAME.state"
  rm -f "$STATE_DIR/failed/$NAME.state"
}

function mark_failed() {
  echo "$(date '+%s')" > "$STATE_DIR/failed/$NAME.state"
}

if [[ -f "$STATE_DIR/success/$NAME.state" ]]; then
  log "[SKIP] already up to date"
  exit 0
fi

log "[START] $URL"

ATTEMPT=0
MAX_ATTEMPTS=3

until [[ $ATTEMPT -ge $MAX_ATTEMPTS ]]; do
  if ./local-mirror.sh --url "$URL" --dest "$DEST"; then
    log "[OK] mirror complete"
    log "[SIZE] $(du -sh "$DEST" 2>/dev/null | cut -f1)"
    mark_success
    exit 0
  fi

  ATTEMPT=$((ATTEMPT+1))
  log "[RETRY] attempt $ATTEMPT/$MAX_ATTEMPTS"

  sleep $((2 ** ATTEMPT))
done

log "[FAIL] exhausted retries"
mark_failed

exit 1
