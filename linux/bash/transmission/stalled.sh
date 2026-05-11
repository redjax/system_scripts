#!/usr/bin/env bash
set -euo pipefail

THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${THIS_DIR}/_common.sh"

RM_STALLED="false"

function usage() {
  cat << 'EOF'
Usage: stalled.sh [OPTIONS]

  -h, --help                   Print this help menu
  -H, --host     <ip-or-fqdn>   Transmission server address
  -p, --port     <port>         Transmission port
  -u, --username <string>       Transmission RPC username
  -P, --password <string>       Transmission RPC password
  --rm-stalled                  Removes all torrents in 'stalled' state
  --debug                       Enable debug logging
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
      --rm-stalled)
        RM_STALLED="true"
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
  local required=(TRANSMISSION_HOST TRANSMISSION_PORT TRANSMISSION_USERNAME TRANSMISSION_PASSWORD)
  for var in "${required[@]}"; do
    if [[ -z "${!var}" ]]; then
      echo "[ERROR] Missing required config: $var" >&2
      echo "Set via env vars or CLI args (-u/-P for credentials)" >&2
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

TOTAL_TORRENTS=$(count_torrents "$SESSION_ID" "$RPC_URL" "$TRANSMISSION_AUTH_STR")
[[ $TOTAL_TORRENTS -gt 0 ]] && echo "Found [$TOTAL_TORRENTS] torrent(s)"

echo
list_stalled_torrents "$SESSION_ID" "$RPC_URL" "$TRANSMISSION_AUTH_STR"

if [[ "$RM_STALLED" == "true" ]]; then
  STALLED_TORRENTS=$(count_stalled_torrents "$SESSION_ID" "$RPC_URL" "$TRANSMISSION_AUTH_STR")
  [[ $STALLED_TORRENTS -eq 0 ]] && { echo "No stalled torrents to remove"; exit 0; }

  echo "Removing $STALLED_TORRENTS stalled torrents"
  remove_stalled_torrents "$SESSION_ID" "$RPC_URL" "$TRANSMISSION_AUTH_STR" "false"
fi
