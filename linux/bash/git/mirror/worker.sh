#!/usr/bin/env bash
set -euo pipefail

URL="$1"
DEST="$2"
AUTH_MODE="${3:-none}"

SSH_KEY=""

case "$AUTH_MODE" in
  ssh)
    ## Rely on ssh-agent / ~/.ssh/config
    ;;
    
  github)
    export GIT_TOKEN_GITHUB="${GIT_TOKEN_GITHUB:-}"
    ;;
    
  gitlab)
    export GIT_TOKEN_GITLAB="${GIT_TOKEN_GITLAB:-}"
    ;;
    
  none)
    ;;
    
  *)
    echo "[ERROR] Unknown auth mode: $AUTH_MODE"
    exit 1
    ;;
esac

./local-mirror.sh \
  --url "$URL" \
  --dest "$DEST"
