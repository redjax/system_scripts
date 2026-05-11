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

REPOS_DIR="${MIRROR_REPOS_DIR:-$DIR/repos}"
STATE_DIR="${MIRROR_STATE_DIR:-$DIR/state}"
LOG_DIR="${MIRROR_LOG_DIR:-$DIR/logs}"

STATUS_MODE=0
RETRY_FAILED=0
DRY_RUN=0

function usage() {
  cat << EOF
Usage:
  $0 [OPTIONS]

Options:
  -f, --repos-file     Path to repos file (required)
  -j, --max-jobs       Max parallel jobs (default: 5)
  --repos-dir          Directory to store repos (default: ./repos)
  --state-dir          State directory (default: ./state)
  --log-dir            Log directory (default: ./logs)
  --retry-failed       Only retry failed repos
  --dry-run            Show what would be executed
  --status             Show mirrored repos status
  -h, --help           Show help
EOF
}

function repo_disk_usage() {
  local dest="$1"
  [[ -d "$dest" ]] && du -sh "$dest" 2>/dev/null | cut -f1 || echo "0"
}

function show_status() {
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
    echo "   SIZE:  $(repo_disk_usage "$dest")"

    if [[ -f "$success_file" ]]; then
      echo "   STATE: + SUCCESS"
    elif [[ -f "$failed_file" ]]; then
      echo "   STATE: x FAILED"
    else
      echo "   STATE: - NEVER RUN"
    fi

    if [[ -f "$log_file" ]]; then
      echo "   LOG:   yes"
    else
      echo "   LOG:   no"
    fi

    echo ""
  done < "$REPOS_FILE"
}

function build_input() {
  if [[ "$RETRY_FAILED" -eq 1 ]]; then
    while read -r url dest auth; do
      [[ -z "$url" || "$url" == \#* ]] && continue
      name="$(basename "$dest")"
      [[ -f "$STATE_DIR/failed/$name.state" ]] && echo "$url|$dest|$auth"
    done < "$REPOS_FILE"
  else
    while read -r url dest auth; do
      [[ -z "$url" || "$url" == \#* ]] && continue
      echo "$url|$dest|$auth"
    done < "$REPOS_FILE"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -f|--repos-file)
      REPOS_FILE="$2"; shift 2 ;;
    -j|--max-jobs)
      MAX_JOBS="$2"; shift 2 ;;
    --repos-dir)
      REPOS_DIR="$2"; shift 2 ;;
    --state-dir)
      STATE_DIR="$2"; shift 2 ;;
    --log-dir)
      LOG_DIR="$2"; shift 2 ;;
    --retry-failed)
      RETRY_FAILED=1; shift ;;
    --dry-run)
      DRY_RUN=1; shift ;;
    --status)
      STATUS_MODE=1; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "[ERROR] Unknown argument: $1" >&2
      usage
      exit 1 ;;
  esac
done

if [[ "$STATUS_MODE" -eq 1 ]]; then
  show_status
  exit 0
fi

mkdir -p "$REPOS_DIR" "$STATE_DIR"/{success,failed,retries} "$LOG_DIR"

declare -a PIDS=()

function wait_for_slot() {
  while [[ "${#PIDS[@]}" -ge "$MAX_JOBS" ]]; do
    for i in "${!PIDS[@]}"; do
      kill -0 "${PIDS[$i]}" 2>/dev/null || unset "PIDS[$i]"
    done
    PIDS=("${PIDS[@]}")
    sleep 0.2
  done
}

function run_worker() {
  local url="$1"
  local dest="$2"
  local auth="$3"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[DRY-RUN] $url -> $dest ($auth)"
    return 0
  fi

  "$DIR/worker.sh" \
    "$url" \
    "$dest" \
    "$auth" \
    "$STATE_DIR" \
    "$LOG_DIR" &
  PIDS+=("$!")
}

INPUT="$(build_input)"

while IFS="|" read -r url dest auth; do
  [[ -z "$url" ]] && continue

  run_worker "$url" "$dest" "$auth"
  wait_for_slot

done <<< "$INPUT"

wait
echo "[+] all mirrors complete"
