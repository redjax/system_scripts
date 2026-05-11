#!/usr/bin/env bash
set -euo pipefail

###################################################################
# Parallel Git mirror                                             #
#                                                                 #
# This script reads a list of git repositories from a file,       #
# then clones them with --mirror to create a local archived copy. #
#                                                                 #
# The script calls worker.sh in parallel to run multiple mirror   #
# operations concurrently.                                        #
###################################################################

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

REPOS_FILE="${MIRROR_REPOS_FILE:-./repos.txt}"
MAX_JOBS=${MIRROR_MAX_JOBS:-5}
STATUS_MODE=0

function usage() {
  cat << EOF
Usage:
  $0 [OPTIONS]

Options:
  -f, --repos-file   Path to repos file (required)
  -j, --max-jobs     Max parallel jobs (default: 5)
  --status           Show mirrored repos status
  -h, --help         Show help
EOF
}

function show_status() {
  local STATE_DIR="./state"
  local LOG_DIR="./logs"

  echo "[ Git Mirror Status ]"
  echo ""

  while read -r url dest auth; do
    [[ -z "$url" || "$url" == \#* ]] && continue

    local name
    name="$(basename "$dest")"

    local success_file="$STATE_DIR/success/$name.state"
    local failed_file="$STATE_DIR/failed/$name.state"
    local log_file="$LOG_DIR/$name.log"

    echo "📦 $name"
    echo "   URL:   $url"
    echo "   DEST:  $dest"
    echo "   AUTH:  $auth"

    if [[ -f "$success_file" ]]; then
      echo "   STATE: + SUCCESS"
      echo "   LAST SUCCESS: $(date -d @"$(cat "$success_file")" 2>/dev/null || cat "$success_file")"
    elif [[ -f "$failed_file" ]]; then
      echo "   STATE: x FAILED"
      echo "   LAST FAIL: $(date -d @"$(cat "$failed_file")" 2>/dev/null || cat "$failed_file")"
    else
      echo "   STATE: - NEVER RUN"
    fi

    if [[ -f "$log_file" ]]; then
      echo "   LOG:   yes ($(du -h "$log_file" | cut -f1))"
    else
      echo "   LOG:   no"
    fi

    echo ""
  done < "$REPOS_FILE"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -f|--repos-file)
      REPOS_FILE="$2"
      shift 2
      ;;
    -j|--max-jobs)
      MAX_JOBS="$2"
      shift 2
      ;;
    -s|--status)
      STATUS_MODE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[ERROR] Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$REPOS_FILE" ]]; then
  echo "[ERROR] --repos-file is required" >&2
  usage
  exit 1
fi

if [[ ! -f "$REPOS_FILE" ]]; then
  echo "[ERROR] file not found: $REPOS_FILE" >&2
  exit 1
fi

declare -a PIDS=()

function wait_for_slot() {
  while [[ "${#PIDS[@]}" -ge "$MAX_JOBS" ]]; do
    for i in "${!PIDS[@]}"; do
      if ! kill -0 "${PIDS[$i]}" 2>/dev/null; then
        unset "PIDS[$i]"
      fi
    done
    PIDS=("${PIDS[@]}")
    sleep 0.2
  done
}

function run_worker() {
  local url="$1"
  local dest="$2"
  local auth="$3"

  "$DIR/worker.sh" "$url" "$dest" "$auth" &
  PIDS+=("$!")
}

while read -r url dest auth; do
  [[ -z "$url" || "$url" == \#* ]] && continue

  run_worker "$url" "$dest" "$auth"
  wait_for_slot

done < "$REPOS_FILE"

wait
echo "[+] all mirrors complete"
