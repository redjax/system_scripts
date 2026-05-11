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

NAME="$(basename "$DEST")"
LOG_DIR="./logs"
STATE_DIR="./state"

mkdir -p "$LOG_DIR" "$STATE_DIR"/{success,failed,retries}

LOG_FILE="$LOG_DIR/$NAME.log"
STATE_FILE="$STATE_DIR/$NAME.state"

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

## Skip successful runs unless forced
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
    mark_success
    exit 0
  fi

  ATTEMPT=$((ATTEMPT+1))
  log "[RETRY] attempt $ATTEMPT/$MAX_ATTEMPTS"

  ## Exponential backoff
  sleep $((2 ** ATTEMPT))
done

log "[FAIL] exhausted retries"
mark_failed

exit 1
