#!/usr/bin/env bash
set -euo pipefail

## Global config
TRANSMISSION_HOST="${TRANSMISSION_HOST:-localhost}"
TRANSMISSION_PORT="${TRANSMISSION_PORT:-9091}"
TRANSMISSION_USERNAME="${TRANSMISSION_USERNAME:-}"
TRANSMISSION_PASSWORD="${TRANSMISSION_PASSWORD:-}"
DEBUG="false"

## Core Functions

function check_dependencies() {
  local deps=(curl jq)
  for dep in "${deps[@]}"; do
    if ! command -v "$dep" &>/dev/null; then
      echo "[ERROR] Script requires $dep" >&2
      exit 1
    fi
  done
}

function usage() {
  cat << EOF
Usage: ${0##*/} [OPTIONS]

  -h, --help               Print this help menu
  -H, --host <ip-or-fqdn>  Transmission server address
  -p, --port <port>        Transmission port
  --debug                  Enable debug logging
EOF
}

function debug() {
  if [[ "$DEBUG" == "true" ]]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') [DEBUG] $*" >&2
  fi
}

function parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      -H|--host) 
        if [[ -z "$2" ]]; then
          echo "[ERROR] --host requires argument" >&2
          usage
          exit 1
        fi
        TRANSMISSION_HOST="$2"
        shift 2
        ;;
      -p|--port)
        if [[ -z "$2" ]]; then
          echo "[ERROR] --port requires argument" >&2
          usage
          exit 1
        fi

        TRANSMISSION_PORT="$2"
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
  local required=(TRANSMISSION_HOST TRANSMISSION_PORT TRANSMISSION_USERNAME TRANSMISSION_PASSWORD)

  for var in "${required[@]}"; do
    if [[ -z "${!var}" ]]; then
      echo "[ERROR] Missing required config: $var" >&2
      usage
      exit 1
    fi
  done
}

function get_session_id() {
  local auth="$1"
  local url="$2"
  
  debug "Fetching session ID from $url"
  local response
  response=$(curl -s -w "\nHTTP_CODE:%{http_code}" -u "$auth" "$url" 2>/dev/null)

  local http_code=$(echo "$response" | grep 'HTTP_CODE:' | cut -d: -f2 | tr -d '[:space:]')
  local body=$(echo "$response" | sed '/HTTP_CODE:/d')
  
  debug "HTTP response code (409 expected): $http_code"
  
  ## Extract from HTML body (handles 409 case)
  local session=$(echo "$body" | grep -oP 'X-Transmission-Session-Id: \K[^<]+' || \
                  grep -oP "(?<=X-Transmission-Session-Id: )[\w\d-]+" "$body")
  
  if [[ -z "$session" ]]; then
    echo "[ERROR] No session ID found. Response snippet:" >&2
    echo "${body:0:200}" >&2
    exit 1
  fi
  
  debug "Session ID: ${session:0:8}"
  echo "$session"
}

## Pre-flight
check_dependencies
parse_arguments "$@"
validate_config

## Setup connection details
readonly TRANSMISSION_AUTH_STR="${TRANSMISSION_USERNAME}:${TRANSMISSION_PASSWORD}"
readonly RPC_URL="http://${TRANSMISSION_HOST}:${TRANSMISSION_PORT}/transmission/rpc"
SESSION_ID=$(get_session_id "$TRANSMISSION_AUTH_STR" "$RPC_URL")

debug_vars() {
  debug "Host: ${TRANSMISSION_HOST}"
  debug "Port: ${TRANSMISSION_PORT}" 
  debug "Username: ${TRANSMISSION_USERNAME}"
}

debug_vars

echo "Connected to ${TRANSMISSION_USERNAME}:<hidden>@${TRANSMISSION_HOST}:${TRANSMISSION_PORT}"
echo "Session ready. Ready for torrent operations."
