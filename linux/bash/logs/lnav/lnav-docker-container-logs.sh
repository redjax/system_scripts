#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME=""
LOG_TAIL=500

function usage() {
  echo ""
  echo "${0##*/} [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  -h, --help                    Print this help menu"
  echo "  -n, --container-name <name>   The name of the container to watch"
  echo "  -t, --tail           <int>    Number of log lines to tail"
  echo ""
}

while [[ $# -gt 0 ]]; do
  case $1 in
    -n|--container-name)
      CONTAINER_NAME="$2"
      shift 2
      ;;
    -t|--tail)
      LOG_TAIL="$2"
      shift 2
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

if [[ -z "$CONTAINER_NAME" ]]; then
  echo "[ERROR] Missing container name to watch" >&2
  echo ""
  usage
  exit 1
fi

echo "Tailing logs for container '$CONTAINER_NAME' (tail=$LOG_TAIL)"

docker logs -f --tail "$LOG_TAIL" "$CONTAINER_NAME" 2>&1 | lnav

