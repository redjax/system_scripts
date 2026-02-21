#!/usr/bin/env bash
set -euo pipefail

##
# Gotify notification helper script #
#
# Examples:
#
# Send a notification from the shell:
#   ./gotify-notification-helper.sh \
#     -u https://gotify.example.com \
#     -f /path/to/gotify-token-file \
#     -t "Example notification title" \
#     -m "This is an example message from $(hostname) at $(date)" \
#     -p 8
#
# Send notification on cron job:
#   0 2 * * * /home/jack/clean_b2_signal_backups.sh >/dev/null 2>&1 || \
#     /usr/local/bin/gotify-notify \
#     -u https://gotify.spooki.one \
#     -f /root/.secrets/gotify_token \
#     -t "Signal Backup Cleanup Failed" \
#     -m "Cleanup failed on $(hostname) at $(date)" \
#     -p 8
##

## Var defaults
GOTIFY_URL=""
TOKEN_FILE=""
TOKEN=""
TITLE=""
MESSAGE=""
PRIORITY=5

function _usage() {
  cat <<EOF

Usage: ${0} [OPTIONS]

Options:
  -h, --help                 Print this help menu
  -u, --url        <string>  URL to Gotify server (required)
  -t, --title      <string>  Notification title
  -m, --message    <string>  Message body (required)
  -p, --priority   <int>     Priority (0-10, default: 5)
  -T, --token      <string>  Raw Gotify token
  -f, --token-file <string>  Path to file containing Gotify token

Examples:
  ${0} -u https://gotify.example.com -f /root/token -m "Backup failed"
  ${0} -u https://gotify.example.com -T ABC123 -t "Alert" -m "Disk full" -p 8

EOF
}

## Parse CLI arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
  -u | --url)
    GOTIFY_URL="$2"
    shift 2
    ;;
  -t | --title)
    TITLE="$2"
    shift 2
    ;;
  -m | --message)
    MESSAGE="$2"
    shift 2
    ;;
  -p | --priority)
    PRIORITY="$2"
    shift 2
    ;;
  -T | --token)
    TOKEN="$2"
    shift 2
    ;;
  -f | --token-file)
    TOKEN_FILE="$2"
    shift 2
    ;;
  -h | --help)
    _usage
    exit 0
    ;;
  *)
    echo "[ERROR] Invalid argument: $1" >&2
    _usage
    exit 1
    ;;
  esac
done

## Validate Inputs
if [[ -z "$GOTIFY_URL" ]]; then
  echo "[ERROR] --url is required" >&2
  exit 1
fi

if [[ -z "$MESSAGE" ]]; then
  echo "[ERROR] --message is required" >&2
  exit 1
fi

if [[ -z "$TOKEN" && -z "$TOKEN_FILE" ]]; then
  echo "[ERROR] Provide --token or --token-file" >&2
  exit 1
fi

if [[ -n "$TOKEN_FILE" ]]; then
  if [[ ! -f "$TOKEN_FILE" ]]; then
    echo "[ERROR] Token file not found: $TOKEN_FILE" >&2
    exit 1
  fi
  TOKEN="$(<"$TOKEN_FILE")"
fi

## Remove trailing slash from URL
GOTIFY_URL="${GOTIFY_URL%/}"

## Default title
if [[ -z "$TITLE" ]]; then
  TITLE="Notification from $(hostname)"
fi

## Validate priority
if ! [[ "$PRIORITY" =~ ^[0-9]+$ ]] || ((PRIORITY < 0 || PRIORITY > 10)); then
  echo "[ERROR] Priority must be integer between 0 and 10" >&2
  exit 1
fi

## Send Notification
read -r BODY STATUS < <(
  curl -sS \
    --connect-timeout 5 \
    --max-time 15 \
    --retry 3 \
    --retry-delay 2 \
    --retry-connrefused \
    -w "\n%{http_code}" \
    -X POST "$GOTIFY_URL/message?token=$TOKEN" \
    -F "title=$TITLE" \
    -F "message=$MESSAGE" \
    -F "priority=$PRIORITY"
)

## Network failure
if [[ -z "$STATUS" ]]; then
  echo "[ERROR] Curl failed (network/TLS issue)" >&2
  exit 2
fi

## Gotify HTTP error
if ((STATUS < 200 || STATUS >= 300)); then
  echo "[ERROR] Gotify returned HTTP $STATUS" >&2
  echo "Response body: $BODY" >&2
  exit 3
fi

exit 0
