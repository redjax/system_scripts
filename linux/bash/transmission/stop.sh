#!/usr/bin/env bash
set -euo pipefail

THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${THIS_DIR}/_common.sh"

IDS=()
ALL="false"
ACTION_METHOD="torrent-stop"
ACTION_NAME="Stop"

function usage() {
  cat << 'EOF'
Usage: stop.sh [OPTIONS]

  -h, --help                   Print this help menu
  -H, --host <ip-or-fqdn>      Transmission server address
  -p, --port <port>            Transmission port
  -u, --username <string>      Transmission RPC username
  -P, --password <string>      Transmission RPC password
  --id <torrent-id>            Target a torrent; may be repeated
  --all                        Stop all torrents
  --debug                      Enable debug logging
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
      --id)
        [[ -z "${2:-}" ]] && { echo "[ERROR] --id requires argument" >&2; usage; exit 1; }
        IDS+=("$2")
        shift 2
        ;;
      --all)
        ALL="true"
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
    [[ -n "${!var}" ]] || { echo "[ERROR] Missing required config: $var" >&2; usage; exit 1; }
  done

  [[ "$ALL" == "true" || ${#IDS[@]} -gt 0 ]] || { echo "[ERROR] Provide one or more --id values or --all" >&2; usage; exit 1; }
}

function build_ids_json() {
  printf '%s\n' "${IDS[@]}" | jq -R 'tonumber' | jq -s .
}

function verify_state() {
  local ids_json="$1"
  curl -s -u "$TRANSMISSION_AUTH_STR" -H "X-Transmission-Session-Id: $SESSION_ID" \
    -d "{\"method\":\"torrent-get\",\"arguments\":{\"ids\":$ids_json,\"fields\":[\"id\",\"name\",\"status\",\"isStalled\"]}}" \
    "$RPC_URL" | jq -r '.arguments.torrents[] | "\(.id): \(.name) | status=\(.status) | stalled=\(.isStalled)"'
}

check_dependencies
parse_arguments "$@"
validate_config

readonly TRANSMISSION_AUTH_STR="${TRANSMISSION_USERNAME}:${TRANSMISSION_PASSWORD}"
readonly RPC_URL="http://${TRANSMISSION_HOST}:${TRANSMISSION_PORT}/transmission/rpc"
SESSION_ID=$(get_session_id "$TRANSMISSION_AUTH_STR" "$RPC_URL")

echo "Connected to ${TRANSMISSION_USERNAME}:<hidden>@${TRANSMISSION_HOST}:${TRANSMISSION_PORT}"

if [[ "$ALL" == "true" ]]; then
  response=$(rpc_torrent_action "$SESSION_ID" "$RPC_URL" "$TRANSMISSION_AUTH_STR" "$ACTION_METHOD" "")
  echo "$response" | jq .
  echo
  curl -s -u "$TRANSMISSION_AUTH_STR" -H "X-Transmission-Session-Id: $SESSION_ID" \
    -d '{"method":"torrent-get","arguments":{"fields":["id","name","status","isStalled"]}}' \
    "$RPC_URL" | jq -r '.arguments.torrents[] | "\(.id): \(.name) | status=\(.status) | stalled=\(.isStalled)"'
else
  ids_json=$(build_ids_json)
  response=$(rpc_torrent_action "$SESSION_ID" "$RPC_URL" "$TRANSMISSION_AUTH_STR" "$ACTION_METHOD" "$ids_json")
  echo "$response" | jq .
  echo
  verify_state "$ids_json"
fi

echo "${ACTION_NAME} request sent"
