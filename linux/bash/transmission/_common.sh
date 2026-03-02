#!/usr/bin/env bash
set -euo pipefail

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
  
  local response=$(curl -s -w "\nHTTP_CODE:%{http_code}" -u "$auth" "$url" 2>/dev/null)
  local http_code=$(echo "$response" | grep 'HTTP_CODE:' | cut -d: -f2 | tr -d '[:space:]')
  local body=$(echo "$response" | sed '/HTTP_CODE:/d')
  
  debug "HTTP response code (409 expected): $http_code"
  
  local session=$(echo "$body" | grep -oP 'X-Transmission-Session-Id: \K[^<]+' || \
                  grep -oP "(?<=X-Transmission-Session-Id: )[\w\d-]+" "$body")
  
  [[ -z "$session" ]] && {
    echo "[ERROR] No session ID found. Response snippet:" >&2
    echo "${body:0:200}" >&2
    exit 1
  }
  
  debug "Session ID: ${session:0:8}..."
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
