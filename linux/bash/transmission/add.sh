#!/usr/bin/env bash
set -euo pipefail

THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${THIS_DIR}/_common.sh"

TORRENT_LINK=""
PAUSED="false"

function usage() {
  cat << 'EOF'
Usage: add.sh [OPTIONS]

  -h, --help                       Print this help menu
  -H, --host         <ip-or-fqdn>  Transmission server address
  -p, --port         <port>        Transmission port
  -u, --username     <string>      Transmission RPC username
  -P, --password     <string>      Transmission RPC password
  -l, --link, --url  <url>         Torrent URL or magnet link
  --paused                         Add torrent in paused state
  --debug                          Enable debug logging
EOF
}

function parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      -H|--host)
        [[ -z "${2:-}" ]] && { echo "[ERROR] --host requires argument" >&2; usage; exit 1; }
        TRANSMISSION_HOST="$2"
        shift 2
        ;;
      -p|--port)
        [[ -z "${2:-}" ]] && { echo "[ERROR] --port requires argument" >&2; usage; exit 1; }
        TRANSMISSION_PORT="$2"
        shift 2
        ;;
      -u|--username)
        [[ -z "${2:-}" ]] && { echo "[ERROR] --username requires argument" >&2; usage; exit 1; }
        TRANSMISSION_USERNAME="$2"
        shift 2
        ;;
      -P|--password)
        [[ -z "${2:-}" ]] && { echo "[ERROR] --password requires argument" >&2; usage; exit 1; }
        TRANSMISSION_PASSWORD="$2"
        shift 2
        ;;
      -l|--link|--url)
        [[ -z "${2:-}" ]] && { echo "[ERROR] --link requires argument" >&2; usage; exit 1; }
        TORRENT_LINK="$2"
        shift 2
        ;;
      --paused)
        PAUSED="true"
        shift
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
        echo "[ERROR] Invalid arg: $1" >&2
        usage
        exit 1
        ;;
    esac
  done
}

function validate_config() {
  local required=(TRANSMISSION_HOST TRANSMISSION_PORT TRANSMISSION_USERNAME TRANSMISSION_PASSWORD TORRENT_LINK)
  for var in "${required[@]}"; do
    if [[ -z "${!var}" ]]; then
      echo "[ERROR] Missing required config: $var" >&2
      usage
      exit 1
    fi
  done
}

check_dependencies
parse_arguments "$@"
validate_config

readonly TRANSMISSION_AUTH_STR="${TRANSMISSION_USERNAME}:${TRANSMISSION_PASSWORD}"
readonly RPC_URL="http://${TRANSMISSION_HOST}:${TRANSMISSION_PORT}/transmission/rpc"
SESSION_ID=$(get_session_id "$TRANSMISSION_AUTH_STR" "$RPC_URL")

echo "Connected to ${TRANSMISSION_USERNAME}:<hidden>@${TRANSMISSION_HOST}:${TRANSMISSION_PORT}"

response=$(rpc_torrent_add "$SESSION_ID" "$RPC_URL" "$TRANSMISSION_AUTH_STR" "$TORRENT_LINK" "$PAUSED")
echo "$response" | jq .

if echo "$response" | jq -e '.result == "success"' >/dev/null; then
  echo "Add request sent"
else
  echo "[ERROR] Add request failed" >&2
  exit 1
fi
