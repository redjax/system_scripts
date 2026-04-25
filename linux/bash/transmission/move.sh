#!/usr/bin/env bash
set -euo pipefail

THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${THIS_DIR}/_common.sh"

IDS=()
ALL="false"
LOCATION=""

function usage() {
  cat << 'EOF'
Usage: move.sh [OPTIONS]

  -h, --help                   Print this help menu
  -H, --host <ip-or-fqdn>      Transmission server address
  -p, --port <port>            Transmission port
  -u, --username <string>      Transmission RPC username
  -P, --password <string>      Transmission RPC password
  --id <torrent-id>            Target a torrent; may be repeated
  --all                        Move all torrents
  -l, --location <path>        New download location
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
      -l|--location)
        [[ -z "${2:-}" ]] && { echo "[ERROR] --location requires argument" >&2; usage; exit 1; }
        LOCATION="$2"
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
        echo "[ERROR] Invalid arg: $1" >&2
        usage
        exit 1
        ;;
    esac
  done
}

function validate_config() {
  local required=(TRANSMISSION_HOST TRANSMISSION_PORT TRANSMISSION_USERNAME TRANSMISSION_PASSWORD LOCATION)
  for var in "${required[@]}"; do
    [[ -n "${!var}" ]] || { echo "[ERROR] Missing required config: $var" >&2; usage; exit 1; }
  done

  [[ "$ALL" == "true" || ${#IDS[@]} -gt 0 ]] || { echo "[ERROR] Provide one or more --id values or --all" >&2; usage; exit 1; }
}

check_dependencies
parse_arguments "$@"
validate_config

readonly TRANSMISSION_AUTH_STR="${TRANSMISSION_USERNAME}:${TRANSMISSION_PASSWORD}"
readonly RPC_URL="http://${TRANSMISSION_HOST}:${TRANSMISSION_PORT}/transmission/rpc"
SESSION_ID=$(get_session_id "$TRANSMISSION_AUTH_STR" "$RPC_URL")

echo "Connected to ${TRANSMISSION_USERNAME}:<hidden>@${TRANSMISSION_HOST}:${TRANSMISSION_PORT}"

if [[ "$ALL" == "true" ]]; then
  ids_json=$(rpc_list_all_torrent_ids "$SESSION_ID" "$RPC_URL" "$TRANSMISSION_AUTH_STR")
else
  ids_json=$(build_ids_json "${IDS[@]}")
fi

response=$(rpc_torrent_move "$SESSION_ID" "$RPC_URL" "$TRANSMISSION_AUTH_STR" "$ids_json" "$LOCATION")
echo "$response" | jq .

echo "Move request sent"
