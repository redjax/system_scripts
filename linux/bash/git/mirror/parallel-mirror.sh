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

REPOS_FILE="${REPOS_FILE:-${DIR}/repos.txt}"
MAX_JOBS="${MAX_JOBS:-5}"

REPOS_DIR="${REPOS_DIR:-${DIR}/repos}"
STATE_DIR="${STATE_DIR:-${DIR}/state}"
LOG_DIR="${LOG_DIR:-${DIR}/logs}"

STATUS_MODE=0
RETRY_FAILED=0
DRY_RUN=0

GITHUB_TOKEN="${GIT_GITHUB_TOKEN:-}"
GITLAB_TOKEN="${GIT_GITLAB_TOKEN:-}"
CODEBERG_TOKEN="${GIT_CODEBERG_TOKEN:-}"

## Prevent interactive SSH prompts during unattended runs
export GIT_SSH_COMMAND="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new"

function usage() {
  cat << EOF
Usage:
  $0 [OPTIONS]

Options:
  -f, --repos-file     Path to repos file
  -j, --max-jobs       Max parallel jobs (default: 5)
  --repos-dir          Directory to store repos
  --state-dir          State directory
  --log-dir            Log directory
  --retry-failed       Only retry failed repos
  --dry-run            Show what would be executed
  --status             Show mirrored repos status
  -h, --help           Show help
EOF
}

function cleanup() {
  echo ""
  echo "[!] shutting down workers..."

  jobs -pr | xargs -r kill 2>/dev/null || true

  wait || true
}

trap cleanup INT TERM

function detect_provider() {
  case "$1" in
    *github.com*) echo "github" ;;
    *gitlab.com*) echo "gitlab" ;;
    *codeberg.org*) echo "codeberg" ;;
    *) echo "none" ;;
  esac
}

function resolve_token() {
  case "$1" in
    github) echo "$GITHUB_TOKEN" ;;
    gitlab) echo "$GITLAB_TOKEN" ;;
    codeberg) echo "$CODEBERG_TOKEN" ;;
    *) echo "" ;;
  esac
}

function repo_disk_usage() {
  [[ -d "$1" ]] && du -sh "$1" 2>/dev/null | cut -f1 || echo "-"
}

function show_status() {
  echo "[ Git Mirror Status ]"
  echo ""

  while read -r url dest auth; do
    [[ -z "$url" || "$url" == \#* ]] && continue

    name="$(basename "$dest")"

    success_file="$STATE_DIR/success/$name.state"
    failed_file="$STATE_DIR/failed/$name.state"

    echo "📦 $name"
    echo "   URL:   $url"
    echo "   DEST:  $dest"
    echo "   SIZE:  $(repo_disk_usage "$dest")"

    if [[ -f "$success_file" ]]; then
      echo "   STATE: + SUCCESS"
    elif [[ -f "$failed_file" ]]; then
      echo "   STATE: x FAILED"
    else
      echo "   STATE: - NEVER RUN"
    fi

    echo ""
  done < "$REPOS_FILE"
}

function build_input() {
  if [[ "$RETRY_FAILED" -eq 1 ]]; then
    while read -r url dest auth; do
      [[ -z "$url" || "$url" == \#* ]] && continue

      name="$(basename "$dest")"

      if [[ -f "$STATE_DIR/failed/$name.state" ]]; then
        echo "$url|$dest|$auth"
      fi
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
      REPOS_FILE="$2"
      shift 2
      ;;

    -j|--max-jobs)
      MAX_JOBS="$2"
      shift 2
      ;;

    --repos-dir)
      REPOS_DIR="$2"
      shift 2
      ;;

    --state-dir)
      STATE_DIR="$2"
      shift 2
      ;;

    --log-dir)
      LOG_DIR="$2"
      shift 2
      ;;

    --retry-failed)
      RETRY_FAILED=1
      shift
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
      echo "[ERROR] Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ "$STATUS_MODE" -eq 1 ]]; then
  show_status
  exit 0
fi

if [[ ! -f "$REPOS_FILE" ]]; then
  echo "[ERROR] repos file not found: $REPOS_FILE" >&2
  exit 1
fi

mkdir -p \
  "$REPOS_DIR" \
  "$STATE_DIR/success" \
  "$STATE_DIR/failed" \
  "$STATE_DIR/retries" \
  "$LOG_DIR"

declare -a PIDS=()

function wait_for_slot() {
  while (( ${#PIDS[@]} >= MAX_JOBS )); do
    for i in "${!PIDS[@]}"; do
      if ! kill -0 "${PIDS[$i]}" 2>/dev/null; then
        unset "PIDS[$i]"
      fi
    done

    # re-index sparse array
    PIDS=("${PIDS[@]}")

    sleep 0.2
  done
}

function run_worker() {
  local url="$1"
  local dest="$2"
  local auth="$3"
  local token="$4"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[DRY] $url -> $dest ($auth)"
    return 0
  fi

  "$DIR/worker.sh" \
    "$url" \
    "$dest" \
    "$auth" \
    "$token" \
    "$STATE_DIR" \
    "$LOG_DIR" &

  PIDS+=("$!")
}

while IFS="|" read -r url dest auth; do
  [[ -z "$url" ]] && continue

  provider="$(detect_provider "$url")"
  token="$(resolve_token "$provider")"

  wait_for_slot
  run_worker "$url" "$dest" "$auth" "$token"

done < <(build_input)

wait

echo "[+] all mirrors complete"
