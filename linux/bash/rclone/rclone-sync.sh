#!/usr/bin/env bash
set -euo pipefail

if ! command -v rclone >/dev/null 2>&1; then
  echo "[ERROR] rclone is not installed" >&2
  exit 1
fi

LOCAL_PATH="${RCLONE_LOCAL_PATH:-}"

RCLONE_REMOTE_NAME="${RCLONE_REMOTE_NAME:-}"
RCLONE_BUCKET_NAME="${RCLONE_BUCKET_NAME:-}"
RCLONE_BUCKET_PATH="${RCLONE_BUCKET_PATH:-}"

RCLONE_TRANSFERS="${RCLONE_TRANSFERS:-8}"
RCLONE_CHECKERS="${RCLONE_CHECKERS:-16}"
RCLONE_UPLOAD_CONCURRENCY="${RCLONE_UPLOAD_CONCURRENCY:-8}"

RCLONE_BWLIMIT="${RCLONE_BWLIMIT:-}"
RCLONE_LOG_FILE="${RCLONE_LOG_FILE:-}"

RCLONE_DRY_RUN="${RCLONE_DRY_RUN:-false}"

function usage() {
  cat <<EOF
Usage: ${0} [OPTIONS]

Options:
  --local-path PATH
  --remote-name NAME
  --bucket-name NAME
  --bucket-path PATH

  --transfers NUM
  --checkers NUM
  --upload-concurrency NUM

  --bwlimit VALUE
  --log-file PATH

  --dry-run

  -h, --help

CLI args override env vars.

Environment variables:
  RCLONE_LOCAL_PATH
  RCLONE_REMOTE_NAME
  RCLONE_BUCKET_NAME
  RCLONE_BUCKET_PATH
  RCLONE_TRANSFERS
  RCLONE_CHECKERS
  RCLONE_UPLOAD_CONCURRENCY
  RCLONE_BWLIMIT
  RCLONE_LOG_FILE
  RCLONE_DRY_RUN

Example:

${0} \
  --local-path /backup/restic \
  --remote-name wasabi-restic \
  --bucket-name jk-restic-backups \
  --bucket-path cybernex

EOF
}

function error() {
  echo "[ERROR] $*" >&2
}

function info() {
  echo "[INFO] $*"
}

## Parse CLI args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --local-path)
      LOCAL_PATH="$2"
      shift 2
      ;;

    --remote-name)
      RCLONE_REMOTE_NAME="$2"
      shift 2
      ;;

    --bucket-name)
      RCLONE_BUCKET_NAME="$2"
      shift 2
      ;;

    --bucket-path)
      RCLONE_BUCKET_PATH="$2"
      shift 2
      ;;

    --transfers)
      RCLONE_TRANSFERS="$2"
      shift 2
      ;;

    --checkers)
      RCLONE_CHECKERS="$2"
      shift 2
      ;;

    --upload-concurrency)
      RCLONE_UPLOAD_CONCURRENCY="$2"
      shift 2
      ;;

    --bwlimit)
      RCLONE_BWLIMIT="$2"
      shift 2
      ;;

    --log-file)
      RCLONE_LOG_FILE="$2"
      shift 2
      ;;

    --dry-run)
      RCLONE_DRY_RUN="true"
      shift
      ;;

    -h|--help)
      usage
      exit 0
      ;;

    *)
      error "Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

[[ -z "$LOCAL_PATH" ]] && {
  error "--local-path or RCLONE_LOCAL_PATH is required"
  exit 1
}

[[ -z "$RCLONE_REMOTE_NAME" ]] && {
  error "--remote-name or RCLONE_REMOTE_NAME is required"
  exit 1
}

[[ -z "$RCLONE_BUCKET_NAME" ]] && {
  error "--bucket-name or RCLONE_BUCKET_NAME is required"
  exit 1
}

if [[ ! -d "$LOCAL_PATH" ]]; then
  error "Local path does not exist: $LOCAL_PATH"
  exit 1
fi

REMOTE_PATH="${RCLONE_REMOTE_NAME}:${RCLONE_BUCKET_NAME}"

if [[ -n "$RCLONE_BUCKET_PATH" ]]; then
  REMOTE_PATH="${REMOTE_PATH}/${RCLONE_BUCKET_PATH}"
fi

LOCK_FILE="/tmp/restic-rclone-sync.lock"

exec 200>"$LOCK_FILE"

flock -n 200 || {
  error "Another sync is already running"
  exit 1
}

RCLONE_ARGS=(
  sync
  "$LOCAL_PATH"
  "$REMOTE_PATH"

  --fast-list

  --transfers="$RCLONE_TRANSFERS"
  --checkers="$RCLONE_CHECKERS"

  --s3-upload-concurrency="$RCLONE_UPLOAD_CONCURRENCY"

  --create-empty-src-dirs

  --stats=30s
  --stats-one-line
  --progress
)

if [[ -n "$RCLONE_BWLIMIT" ]]; then
  RCLONE_ARGS+=(--bwlimit "$RCLONE_BWLIMIT")
fi

if [[ -n "$RCLONE_LOG_FILE" ]]; then
  mkdir -p "$(dirname "$RCLONE_LOG_FILE")"

  RCLONE_ARGS+=(
    --log-file "$RCLONE_LOG_FILE"
    --log-level INFO
  )
fi

if [[ "$RCLONE_DRY_RUN" == "true" ]]; then
  RCLONE_ARGS+=(--dry-run)
fi

info "Starting rclone sync"
info "Source: $LOCAL_PATH"
info "Destination: $REMOTE_PATH"

START_TIME=$(date +%s)

rclone "${RCLONE_ARGS[@]}"

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

info "Sync completed in ${DURATION}s"

