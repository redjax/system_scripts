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
STATUS_MODE=0

mkdir -p "$(dirname "$LOG_FILE")"

function usage() {
  cat << EOF
Usage:
  $0 [OPTIONS]

Options:
  -f, --repos-file   Path to repos file (default: ./repos.txt)
  -j, --max-jobs     Max parallel jobs (default: 5)
  --dry-run          Show actions without running git commands
  --status           Show maintenance targets
  -h, --help         Show help
EOF
}

function repo_name() {
  basename "$1"
}

function log() {
  echo "[$(date '+%F %T')] $*" | tee -a "$LOG_FILE"
}

function run_maintenance() {
  local dest="$1"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "[DRY-RUN] git fsck --full -C $dest"
    log "[DRY-RUN] git gc --auto -C $dest"
    return 0
  fi

  log "[CHECK] $dest"

  if [[ ! -f "$dest/HEAD" ]]; then
    log "[SKIP] not a git repo: $dest"
    return 0
  fi

  git -C "$dest" fsck --full >> "$LOG_FILE" 2>&1 || true
  git -C "$dest" gc --auto >> "$LOG_FILE" 2>&1 || true

  log "[OK] maintenance complete: $dest"
}

function show_status() {
  echo "[ Maintenance Targets ]"
  echo ""

  while read -r url dest auth; do
    [[ -z "$url" || "$url" == \#* ]] && continue

    echo "📦 $(repo_name "$dest")"
    echo "   DEST: $dest"
    echo ""
  done < "$REPOS_FILE"
}

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
    --status)
      STATUS_MODE=1
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

if [[ "$STATUS_MODE" -eq 1 ]]; then
  show_status
  exit 0
fi

if [[ ! -f "$REPOS_FILE" ]]; then
  log "[ERROR] repos file not found: $REPOS_FILE"
  exit 1
fi

log "[START] maintenance run"

while read -r url dest auth; do
  [[ -z "$url" || "$url" == \#* ]] && continue

  if [[ ! -d "$dest" ]]; then
    log "[SKIP] missing repo: $dest"
    continue
  fi

  run_maintenance "$dest" &
  PIDS+=("$!")

  wait_for_slot

done < "$REPOS_FILE"

wait

log "[DONE] maintenance complete"
