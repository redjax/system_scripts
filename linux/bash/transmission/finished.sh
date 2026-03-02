#!/usr/bin/env bash
set -euo pipefail

if ! command -v curl &>/dev/null || ! command -v jq &>/dev/null; then
  echo "[ERROR] Script requires curl and jq" >&2
  exit 1
fi

TRANSMISSION_HOST=${TRANSMISSION_HOST:-localhost}
TRANSMISSION_PORT=${TRANSMISSION_PORT:-9091}
TRANSMISSION_USERNAME=${TRANSMISSION_USERNAME:-}
TRANSMISSION_PASSWORD=${TRANSMISSION_PASSWORD:-}

DEBUG="false"

function usage() {
  echo ""
  echo "Usage: ${0} [OPTIONS]"
  echo ""
  echo "  -h, --help               Print this help menu."
  echo "  -H, --host <ip-or-fqdn>  Transmission server address."
  echo "  -p, --port 9091          Transmission port."
  echo "  --debug                  Enable debug logging."
  echo ""
}

function debug() {
  ts=$(date '+%Y-%m-%d %H:%M:%S')
  [ "$DEBUG" = "true" ] && echo "$ts [DEBUG] $*" >&2
}

## Parse args
while [[ $# -gt 0 ]]; do
  case $1 in
    -H|--host)
      if [[ -z "$2" ]]; then
        echo "[ERROR] --host provided, but no Transmission hostname given"
        usage
        exit 1
      fi

      TRANSMISSION_HOST="$2"
      shift 2
      ;;
    --debug)
      DEBUG="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[ERROR] Invalid arg: $1"
      usage
      exit 1
      ;;
  esac
done

###################
# Validate Inputs #
###################
if [[ -z "${TRANSMISSION_HOST}" ]]; then
  echo "[ERROR] Missing Transmission host" >&2
  usage
  exit 1
fi

if [[ -z "$TRANSMISSION_PORT" ]]; then
  echo "[ERROR] Missing Transmission port" >&2
  usage
  exit 1
fi

if [[ -z "$TRANSMISSION_USERNAME" ]]; then
  echo "[ERROR] Missing Transmission username" >&2
  usage
  exit 1
fi

if [[ -z "$TRANSMISSION_PASSWORD" ]]; then
  echo "[ERROR] Missing Transmission password" >&2
  usage
  exit 1
fi

# debug_vars
debug "Host: ${TRANSMISSION_HOST}"
debug "Port: ${TRANSMISSION_PORT}"
debug "Username: ${TRANSMISSION_USERNAME}"
# debug "Password: ${TRANSMISSION_PASSWORD}"
# debug "Auth string: ${TRANSMISSION_AUTH_STR}"

TRANSMISSION_AUTH_STR="${TRANSMISSION_USERNAME}:${TRANSMISSION_PASSWORD}"
RPC_URL="http://${TRANSMISSION_HOST}:${TRANSMISSION_PORT}/transmission/rpc"

echo ""
echo "Connnecting to host: ${TRANSMISSION_USERNAME}:<password-hidden>@${TRANSMISSION_HOST}:${TRANSMISSION_PORT}"
echo ""

RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -u "$TRANSMISSION_AUTH_STR" "$RPC_URL" 2>/dev/null)
HTTP_CODE=$(echo "$RESPONSE" | grep 'HTTP_CODE:' | cut -d: -f2 | tr -d '[:space:]')
BODY=$(echo "$RESPONSE" | sed '/HTTP_CODE:/d')

debug "HTTP response code (409 is expected/ok): $HTTP_CODE"

# Try header first (if present), then HTML body
SESSION=$(echo "$BODY" | grep -oP 'X-Transmission-Session-Id: \K[^<]+' || \
          grep -oP "(?<=X-Transmission-Session-Id: )[\w\d]+" "$BODY")

if [[ -z "$SESSION" ]]; then
  echo "[ERROR] No session ID found. Response:" >&2
  echo "$BODY" >&2
  exit 1
fi

debug "Session ID: ${SESSION:0:8}"
