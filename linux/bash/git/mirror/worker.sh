#!/usr/bin/env bash
set -euo pipefail

URL="$1"
DEST="$2"
AUTH_MODE="${3:-none}"
TOKEN="${4:-}"
STATE_DIR="${5:-./state}"
LOG_DIR="${6:-./logs}"

mkdir -p "$STATE_DIR"/{success,failed,retries} "$LOG_DIR"

repo_id() {
  printf '%s' "$DEST" | sed 's#^/##; s#/#__#g; s#[[:space:]]\+#_#g'
}

NAME="$(repo_id)"

LOG_FILE="$LOG_DIR/$NAME.log"

function log() {
  echo "[$(date '+%F %T')] $*" | tee -a "$LOG_FILE"
}

function mark_success() {
  echo "$(date +%s)" > "$STATE_DIR/success/$NAME.state"
  rm -f "$STATE_DIR/failed/$NAME.state"
}

function mark_failed() {
  echo "$(date +%s)" > "$STATE_DIR/failed/$NAME.state"
}

log "[START] url=$URL dest=$DEST auth=$AUTH_MODE"

AUTH_URL="$URL"

case "$AUTH_MODE" in
  github)
    [[ -n "$TOKEN" ]] && AUTH_URL="https://x-access-token:${TOKEN}@github.com/${URL#*github.com/}"
    ;;
  gitlab)
    [[ -n "$TOKEN" ]] && AUTH_URL="https://oauth2:${TOKEN}@gitlab.com/${URL#*gitlab.com/}"
    ;;
  codeberg)
    [[ -n "$TOKEN" ]] && AUTH_URL="https://${TOKEN}@codeberg.org/${URL#*codeberg.org/}"
    ;;
  ssh|none)
    AUTH_URL="$URL"
    ;;
esac

ATTEMPT=0
MAX=3

while (( ATTEMPT < MAX )); do

  if [[ ! -d "$DEST" ]]; then
    log "[CLONE] $AUTH_URL -> $DEST"
    git clone --mirror "$AUTH_URL" "$DEST" && break
  else
    log "[FETCH] $URL in $DEST"
    git -C "$DEST" fetch --all --prune && break
  fi

  ATTEMPT=$((ATTEMPT+1))
  log "[RETRY] $ATTEMPT/$MAX"
  sleep $((2 ** ATTEMPT))

done

if (( ATTEMPT >= MAX )); then
  log "[FAIL] $URL"
  mark_failed
  exit 1
fi

log "[OK] $URL"
mark_success
