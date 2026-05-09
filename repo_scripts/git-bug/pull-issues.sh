#!/usr/bin/env bash
set -euo pipefail

if ! command -v git-bug >&/dev/null; then
  echo "[ERROR] git-bug is not installed" >&2
  exit 1
fi

BRIDGE_NAME=""

function usage() {
  echo
  echo "Usage: ${0} [OPTIONS]"
  echo
  echo "Options:"
  echo "  -h, --help     Print this help menu"
  echo
}

while [[ $# -gt 0 ]]; do
  case $1 in
  -h | --help)
    usage
    exit 0
    ;;
  -b | --bridge)
    BRIDGE_NAME="$2"
    shift 2
    ;;
  *)
    echo "[ERROR] Invalid arg: $1" >&2
    usage
    exit 1
    ;;
  esac
done

if [[ -z "${BRIDGE_NAME}" ]]; then
  cmd=(git bug pull)
else
  cmd=(git bug bridge pull "${BRIDGE_NAME}")
fi

echo "Running git-bug pull command"

if ! "${cmd[@]}"; then
  echo "[ERROR] Failed running command: ${cmd[*]}" >&2
  exit 1
fi

