#!/usr/bin/env bash
set -euo pipefail

if ! command -v curl &>/dev/null; then
  echo "[ERROR] curl is not installed." >&2
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "[ERROR] jq is not installed." >&2
  exit 1
fi

## Global config (defaults + env overrides)
: "${TRANSMISSION_HOST:=localhost}"
: "${TRANSMISSION_PORT:=9091}"
: "${TRANSMISSION_USERNAME:=}"
: "${TRANSMISSION_PASSWORD:=}"

## Global state
DEBUG="${DEBUG:-false}"
TOTAL_TORRENTS=""
FINISHED_TORRENTS=""

## Debug logging
function debug() {
  if [[ "$DEBUG" == "true" ]]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') [DEBUG] $*" >&2
  fi
}

## Session management
function get_session_id() {
  local auth="$1" url="$2"
  debug "Fetching session ID from $url"

  local headers
  headers="$(mktemp)"
  trap 'rm -f "$headers"' RETURN

  curl -sS -D "$headers" -o /dev/null -u "$auth" "$url" >/dev/null || true

  local session
  session="$(awk -F': ' 'tolower($1)=="x-transmission-session-id"{gsub("\r","",$2); print $2}' "$headers" | tail -n 1)"

  if [[ -z "$session" ]]; then
    echo "[ERROR] No session ID found in response headers." >&2
    exit 1
  fi

  debug "Session ID: ${session:0:8}"
  echo "$session"
}

## Torrent operations
function count_torrents() {
  local session="$1" url="$2" auth="$3"
  curl -s -u "$auth" -H "X-Transmission-Session-Id: $session" \
    -d '{"method":"torrent-get","arguments":{"fields":["id"]}}' \
    "$url" | jq '.arguments.torrents | length'
}

function count_finished_torrents() {
  local session="$1" url="$2" auth="$3"
  curl -s -u "$auth" -H "X-Transmission-Session-Id: $session" \
    -d '{"method":"torrent-get","arguments":{"fields":["percentDone","status"]}}' \
    "$url" | jq '[.arguments.torrents[] | select(.percentDone == 1 and (.status==0 or .status==6))] | length'
}

function list_finished_torrents() {
  local session="$1" url="$2" auth="$3"
  curl -s -u "$auth" -H "X-Transmission-Session-Id: $session" \
    -d '{"method":"torrent-get","arguments":{"fields":["id","name","percentDone","status"]}}' \
    "$url" | jq -r '.arguments.torrents[] | select(.percentDone == 1 and (.status==0 or .status==6)) | "\(.id): \(.name)"'
}

function remove_finished_torrents() {
  local session="$1" url="$2" auth="$3" delete_data="$4"
  curl -s -u "$auth" -H "X-Transmission-Session-Id: $session" \
    -d '{"method":"torrent-get","arguments":{"fields":["id","percentDone","status"]}}' \
    "$url" | jq -r '.arguments.torrents[] | select(.percentDone == 1 and (.status==0 or .status==6)) | .id' | while read -r torrent_id; do
      [[ -z "$torrent_id" ]] && continue
      echo "Removing torrent ID: $torrent_id"
      curl -s -u "$auth" -H "X-Transmission-Session-Id: $session" \
        -d "{\"method\":\"torrent-remove\",\"arguments\":{\"ids\":[$torrent_id],\"delete-local-data\":$([[ "$delete_data" == "true" ]] && echo true || echo false)}}" \
        "$url" >/dev/null
    done
}

function check_dependencies() {
  local deps=(curl jq)
  for dep in "${deps[@]}"; do
    if ! command -v "$dep" &>/dev/null; then
      echo "[ERROR] Script requires $dep" >&2
      exit 1
    fi
  done
}

function count_stalled_torrents() {
  local session="$1" url="$2" auth="$3"
  curl -s -u "$auth" -H "X-Transmission-Session-Id: $session" \
    -d '{"method":"torrent-get","arguments":{"fields":["id","isStalled"]}}' \
    "$url" | jq '[.arguments.torrents[] | select(.isStalled == true)] | length'
}

function list_stalled_torrents() {
  local session="$1" url="$2" auth="$3"
  curl -s -u "$auth" -H "X-Transmission-Session-Id: $session" \
    -d '{"method":"torrent-get","arguments":{"fields":["id","name","isStalled","status"]}}' \
    "$url" | jq -r '.arguments.torrents[] | select(.isStalled == true) | "\(.id): \(.name)"'
}

function remove_stalled_torrents() {
  local session="$1" url="$2" auth="$3" delete_data="$4"
  curl -s -u "$auth" -H "X-Transmission-Session-Id: $session" \
    -d '{"method":"torrent-get","arguments":{"fields":["id","isStalled"]}}' \
    "$url" | jq -r '.arguments.torrents[] | select(.isStalled == true) | .id' | while read -r torrent_id; do
      [[ -z "$torrent_id" ]] && continue
      echo "Removing stalled torrent ID: $torrent_id"
      curl -s -u "$auth" -H "X-Transmission-Session-Id: $session" \
        -d "{\"method\":\"torrent-remove\",\"arguments\":{\"ids\":[$torrent_id],\"delete-local-data\":$([[ "$delete_data" == "true" ]] && echo true || echo false)}}" \
        "$url" >/dev/null
    done
}

function build_ids_json() {
  printf '%s\n' "$@" | jq -R 'tonumber' | jq -s .
}

function rpc_torrent_action() {
  local session="$1" url="$2" auth="$3" method="$4" ids_json="${5:-}"

  if [[ -n "$ids_json" ]]; then
    jq -n --arg method "$method" --argjson ids "$ids_json" \
      '{method:$method, arguments:{ids:$ids}}' |
      curl -sS -u "$auth" -H "X-Transmission-Session-Id: $session" \
        -H "Content-Type: application/json" \
        -d @- \
        "$url"
  else
    jq -n --arg method "$method" '{method:$method}' |
      curl -sS -u "$auth" -H "X-Transmission-Session-Id: $session" \
        -H "Content-Type: application/json" \
        -d @- \
        "$url"
  fi
}

function rpc_torrent_add() {
  local session="$1" url="$2" auth="$3" link="$4" paused="${5:-false}"

  jq -n --arg method "torrent-add" --arg filename "$link" --argjson paused "$paused" \
    '{method:$method, arguments:{filename:$filename, paused:$paused}}' |
    curl -sS -u "$auth" -H "X-Transmission-Session-Id: $session" \
      -H "Content-Type: application/json" \
      -d @- \
      "$url"
}

function rpc_torrent_remove() {
  local session="$1" url="$2" auth="$3" ids_json="$4" delete_data="${5:-false}"

  jq -n --arg method "torrent-remove" --argjson ids "$ids_json" --argjson delete_local_data "$delete_data" \
    '{method:$method, arguments:{ids:$ids, "delete-local-data":$delete_local_data}}' |
    curl -sS -u "$auth" -H "X-Transmission-Session-Id: $session" \
      -H "Content-Type: application/json" \
      -d @- \
      "$url"
}

function rpc_list_all_torrent_ids() {
  local session="$1" url="$2" auth="$3"
  curl -sS -u "$auth" -H "X-Transmission-Session-Id: $session" \
    -H "Content-Type: application/json" \
    -d '{"method":"torrent-get","arguments":{"fields":["id"]}}' \
    "$url" | jq '[.arguments.torrents[].id]'
}

function rpc_torrent_verify() {
  local session="$1" url="$2" auth="$3" ids_json="$4"

  jq -n --argjson ids "$ids_json" \
    '{method:"torrent-verify", arguments:{ids:$ids}}' |
    curl -sS -u "$auth" -H "X-Transmission-Session-Id: $session" \
      -H "Content-Type: application/json" \
      -d @- \
      "$url"
}

function rpc_torrent_reannounce() {
  local session="$1" url="$2" auth="$3" ids_json="$4"

  jq -n --argjson ids "$ids_json" \
    '{method:"torrent-reannounce", arguments:{ids:$ids}}' |
    curl -sS -u "$auth" -H "X-Transmission-Session-Id: $session" \
      -H "Content-Type: application/json" \
      -d @- \
      "$url"
}

function rpc_torrent_move() {
  local session="$1" url="$2" auth="$3" ids_json="$4" location="$5"

  jq -n --argjson ids "$ids_json" --arg location "$location" \
    '{method:"torrent-set-location", arguments:{ids:$ids, location:$location, move:true}}' |
    curl -sS -u "$auth" -H "X-Transmission-Session-Id: $session" \
      -H "Content-Type: application/json" \
      -d @- \
      "$url"
}
