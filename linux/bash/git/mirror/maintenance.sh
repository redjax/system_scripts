#!/usr/bin/env bash
set -euo pipefail

##################################################################
# Git mirror maintenance                                         #
#                                                                #
# Runs integrity checks (fsck) and optional cleanup (gc)         #
# across all local mirrored repositories defined in repos.txt.   #
#                                                                #
##################################################################

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

REPOS_FILE="${REPOS_FILE:-./repos.txt}"
MAX_JOBS="${MAX_JOBS:-5}"
LOG_FILE="${LOG_FILE:-$DIR/logs/maintenance.log}"

DRY_RUN=0

MODE="all"

mkdir -p "$(dirname "$LOG_FILE")"

function usage() {
  cat << EOF
Usage:
  $0 [OPTIONS]

Options:
  -f, --repos-file          Path to repos file (default: ./repos.txt)
  -j, --max-jobs            Max parallel jobs (default: 5)

  --dry-run                Show actions without executing git commands

  --check-integrity        Run fsck only
  --gc                     Run gc only
  --clean-logs             Run ONLY log cleanup

  -h, --help               Show help
EOF
}

function log() {
  echo "[$(date '+%F %T')] $*" | tee -a "$LOG_FILE"
}

function run_fsck() {
  local dest="$1"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "[DRY-RUN] git fsck --full -C $dest"
    return 0
  fi

  log "[FSCK] $dest"
  git -C "$dest" fsck --full >> "$LOG_FILE" 2>&1 || true
}

function run_gc() {
  local dest="$1"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "[DRY-RUN] git gc --auto -C $dest"
    return 0
  fi

  log "[GC] $dest"
  git -C "$dest" gc --auto >> "$LOG_FILE" 2>&1 || true
}

function cleanup_logs() {
  local log_dir
  log_dir="$(dirname "$LOG_FILE")"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "[DRY-RUN] cleanup logs in $log_dir"
    return 0
  fi

  log "[CLEANUP] logs in $log_dir"

  find "$log_dir" -type f -name "*.log" -mtime +14 -delete 2>/dev/null || true

  log "[CLEANUP] done"
}

function process_repo() {
  local url="$1"
  local dest="$2"

  log "[CHECK] $dest"

  if [[ ! -f "$dest/HEAD" ]]; then
    log "[SKIP] not a git repo: $dest"
    return 0
  fi

  case "$MODE" in
    fsck)
      run_fsck "$dest"
      ;;
    gc)
      run_gc "$dest"
      ;;
    all)
      run_fsck "$dest"
      run_gc "$dest"
      ;;
  esac
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

    --dry-run)
      DRY_RUN=1
      shift
      ;;

    --check-integrity)
      MODE="fsck"
      shift
      ;;

    --gc)
      MODE="gc"
      shift
      ;;

    --clean-logs)
      MODE="logs"
      shift
      ;;

    -h|--help)
      usage
      exit 0
      ;;

    *)
      log "[ERROR] Unknown argument: $1"
      exit 1
      ;;
  esac
done

log "[START] maintenance run"

if [[ "$MODE" == "logs" ]]; then
  cleanup_logs
  log "[DONE] maintenance complete"
  exit 0
fi

declare -a PIDS=()

function wait_for_slot() {
  while (( ${#PIDS[@]} >= MAX_JOBS )); do
    for i in "${!PIDS[@]}"; do
      kill -0 "${PIDS[$i]}" 2>/dev/null || unset "PIDS[$i]"
    done
    PIDS=("${PIDS[@]}")
    sleep 0.2
  done
}

while IFS='|' read -r url dest auth; do
  [[ -z "$url" || "$url" == \#* ]] && continue

  if [[ ! -d "$dest" ]]; then
    log "[SKIP] missing repo: $dest"
    continue
  fi

  process_repo "$url" "$dest" &

  PIDS+=("$!")
  wait_for_slot

done < "$REPOS_FILE"

wait

log "[DONE] maintenance complete"
