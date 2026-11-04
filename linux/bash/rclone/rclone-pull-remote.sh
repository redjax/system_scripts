#!/usr/bin/env bash
set -euo pipefail

##############################################################################
# Pulls a path from an rclone remote to a local directory using rclone sync. #
#                                                                            #
# Usage:                                                                     #
#   rclone sync SOURCE DESTINATION                                           #
#                                                                            #
# The rclone remote must already exist in your config.                       #
#                                                                            #
# Example:                                                                   #
#                                                                            #
#   ./rclone-pull-remote.sh \                                                #
#     --remote-name wasabi \                                                 #
#     --bucket-name my-bucket \                                              #
#     --bucket-path some/path \                                              #
#     --local-path /backup/some/path                                         #
##############################################################################

if ! command -v rclone >/dev/null 2>&1; then
  echo "[ERROR] rclone is not installed" >&2
  exit 1
fi

RCLONE_CONFIG_FILE="${RCLONE_CONFIG_FILE:-"${HOME}/.config/rclone/rclone.conf"}"

LOCAL_PATH="${RCLONE_LOCAL_PATH:-}"
RCLONE_REMOTE_NAME="${RCLONE_REMOTE_NAME:-}"
RCLONE_BUCKET_NAME="${RCLONE_BUCKET_NAME:-}"
RCLONE_BUCKET_PATH="${RCLONE_BUCKET_PATH:-}"

RCLONE_TRANSFERS="${RCLONE_TRANSFERS:-8}"
RCLONE_CHECKERS="${RCLONE_CHECKERS:-16}"

RCLONE_BWLIMIT="${RCLONE_BWLIMIT:-}"
RCLONE_LOG_FILE="${RCLONE_LOG_FILE:-}"

RCLONE_DRY_RUN="${RCLONE_DRY_RUN:-false}"

RCLONE_FAST_LIST="${RCLONE_FAST_LIST:-true}"
RCLONE_PROGRESS="${RCLONE_PROGRESS:-true}"
RCLONE_STATS_INTERVAL="${RCLONE_STATS_INTERVAL:-30s}"

RCLONE_CREATE_EMPTY_SRC_DIRS="${RCLONE_CREATE_EMPTY_SRC_DIRS:-true}"

usage() {
  cat <<EOF
Usage: ${0} [OPTIONS]

Pull a remote rclone path to a local directory using:

  rclone sync REMOTE LOCAL

IMPORTANT:
  This is a one-way remote -> local operation.

Options:
  --config PATH
      rclone config file
      Default: ${HOME}/.config/rclone/rclone.conf

  --local-path PATH
      Local destination directory
      Required

  --remote-name NAME
      rclone remote name
      Required

  --bucket-name NAME
      Remote bucket name
      Required

  --bucket-path PATH
      Path within the bucket
      Optional

  --transfers NUM
      Number of simultaneous file transfers
      Default: ${RCLONE_TRANSFERS}

  --checkers NUM
      Number of simultaneous checkers
      Default: ${RCLONE_CHECKERS}

  --bwlimit VALUE
      Bandwidth limit, e.g. 10M, 100M, 1G
      Optional

  --log-file PATH
      Write rclone log to this file
      Optional

  --dry-run
      Show what would be synchronized without making changes

  --no-fast-list
      Disable --fast-list

  --no-progress
      Disable progress output

  --stats-interval VALUE
      Stats interval
      Default: ${RCLONE_STATS_INTERVAL}

  --no-create-empty-src-dirs
      Disable --create-empty-src-dirs

  -h, --help
      Show this help

CLI arguments override environment variables.

Environment variables:

  RCLONE_CONFIG_FILE
  RCLONE_LOCAL_PATH
  RCLONE_REMOTE_NAME
  RCLONE_BUCKET_NAME
  RCLONE_BUCKET_PATH

  RCLONE_TRANSFERS
  RCLONE_CHECKERS
  RCLONE_BWLIMIT
  RCLONE_LOG_FILE

  RCLONE_DRY_RUN

  RCLONE_FAST_LIST
  RCLONE_PROGRESS
  RCLONE_STATS_INTERVAL
  RCLONE_CREATE_EMPTY_SRC_DIRS

Examples:

  ${0} \\
    --remote-name wasabi \\
    --bucket-name my-bucket \\
    --bucket-path some/path \\
    --local-path /backup/some/path

  ${0} \\
    --config /home/user/.config/rclone/rclone.conf \\
    --remote-name wasabi \\
    --bucket-name my-bucket \\
    --bucket-path photos/2026 \\
    --local-path /backup/photos/2026 \\
    --transfers 16 \\
    --checkers 32 \\
    --log-file /var/log/rclone-pull.log

  ${0} \\
    --remote-name wasabi \\
    --bucket-name my-bucket \\
    --bucket-path photos \\
    --local-path /backup/photos \\
    --dry-run

EOF
}

error() {
  echo "[ERROR] $*" >&2
}

info() {
  echo "[INFO] $*"
}

while [[ $# -gt 0 ]]; do
  case "$1" in

    --config)
      if [[ $# -lt 2 ]]; then
        error "--config requires a value"
        exit 1
      fi
      RCLONE_CONFIG_FILE="$2"
      shift 2
      ;;

    --local-path)
      if [[ $# -lt 2 ]]; then
        error "--local-path requires a value"
        exit 1
      fi
      LOCAL_PATH="$2"
      shift 2
      ;;

    --remote-name)
      if [[ $# -lt 2 ]]; then
        error "--remote-name requires a value"
        exit 1
      fi
      RCLONE_REMOTE_NAME="$2"
      shift 2
      ;;

    --bucket-name)
      if [[ $# -lt 2 ]]; then
        error "--bucket-name requires a value"
        exit 1
      fi
      RCLONE_BUCKET_NAME="$2"
      shift 2
      ;;

    --bucket-path)
      if [[ $# -lt 2 ]]; then
        error "--bucket-path requires a value"
        exit 1
      fi
      RCLONE_BUCKET_PATH="$2"
      shift 2
      ;;

    --transfers)
      if [[ $# -lt 2 ]]; then
        error "--transfers requires a value"
        exit 1
      fi
      RCLONE_TRANSFERS="$2"
      shift 2
      ;;

    --checkers)
      if [[ $# -lt 2 ]]; then
        error "--checkers requires a value"
        exit 1
      fi
      RCLONE_CHECKERS="$2"
      shift 2
      ;;

    --bwlimit)
      if [[ $# -lt 2 ]]; then
        error "--bwlimit requires a value"
        exit 1
      fi
      RCLONE_BWLIMIT="$2"
      shift 2
      ;;

    --log-file)
      if [[ $# -lt 2 ]]; then
        error "--log-file requires a value"
        exit 1
      fi
      RCLONE_LOG_FILE="$2"
      shift 2
      ;;

    --dry-run)
      RCLONE_DRY_RUN="true"
      shift
      ;;

    --no-fast-list)
      RCLONE_FAST_LIST="false"
      shift
      ;;

    --no-progress)
      RCLONE_PROGRESS="false"
      shift
      ;;

    --stats-interval)
      if [[ $# -lt 2 ]]; then
        error "--stats-interval requires a value"
        exit 1
      fi
      RCLONE_STATS_INTERVAL="$2"
      shift 2
      ;;

    --no-create-empty-src-dirs)
      RCLONE_CREATE_EMPTY_SRC_DIRS="false"
      shift
      ;;

    -h | --help)
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

if [[ -z "${RCLONE_CONFIG_FILE}" ]]; then
  error "--config or RCLONE_CONFIG_FILE is required"
  exit 1
fi

if [[ -z "${LOCAL_PATH}" ]]; then
  error "--local-path or RCLONE_LOCAL_PATH is required"
  exit 1
fi

if [[ -z "${RCLONE_REMOTE_NAME}" ]]; then
  error "--remote-name or RCLONE_REMOTE_NAME is required"
  exit 1
fi

if [[ -z "${RCLONE_BUCKET_NAME}" ]]; then
  error "--bucket-name or RCLONE_BUCKET_NAME is required"
  exit 1
fi

if [[ ! -f "${RCLONE_CONFIG_FILE}" ]]; then
  error "rclone config file does not exist: ${RCLONE_CONFIG_FILE}"
  exit 1
fi

REMOTE_PATH="${RCLONE_REMOTE_NAME}:${RCLONE_BUCKET_NAME}"

if [[ -n "${RCLONE_BUCKET_PATH}" ]]; then
  REMOTE_PATH="${REMOTE_PATH}/${RCLONE_BUCKET_PATH#/}"
fi

if [[ ! -d "${LOCAL_PATH}" ]]; then
  info "Creating local destination: ${LOCAL_PATH}"
  mkdir -p "${LOCAL_PATH}"
fi

LOCK_FILE="${XDG_RUNTIME_DIR:-/tmp}/rclone-pull-remote.lock"

exec 200>"${LOCK_FILE}"

if ! flock -n 200; then
  error "Another pull is already running (lock: ${LOCK_FILE})"
  exit 1
fi

echo "PID: $$ USER: $(whoami)" >&200

RCLONE_ARGS=(
  sync
  "${REMOTE_PATH}"
  "${LOCAL_PATH}"
  --transfers="${RCLONE_TRANSFERS}"
  --checkers="${RCLONE_CHECKERS}"
  --stats="${RCLONE_STATS_INTERVAL}"
  --stats-one-line
)

if [[ "${RCLONE_FAST_LIST}" == "true" ]]; then
  RCLONE_ARGS+=(--fast-list)
fi

if [[ "${RCLONE_PROGRESS}" == "true" ]]; then
  RCLONE_ARGS+=(--progress)
fi

if [[ "${RCLONE_CREATE_EMPTY_SRC_DIRS}" == "true" ]]; then
  RCLONE_ARGS+=(--create-empty-src-dirs)
fi

if [[ -n "${RCLONE_BWLIMIT}" ]]; then
  RCLONE_ARGS+=(--bwlimit "${RCLONE_BWLIMIT}")
fi

if [[ -n "${RCLONE_LOG_FILE}" ]]; then
  mkdir -p "$(dirname "${RCLONE_LOG_FILE}")"

  RCLONE_ARGS+=(
    --log-file "${RCLONE_LOG_FILE}"
    --log-level INFO
  )
fi

if [[ "${RCLONE_DRY_RUN}" == "true" ]]; then
  RCLONE_ARGS+=(--dry-run)
fi

info "Starting rclone pull"
info "Source:      ${REMOTE_PATH}"
info "Destination: ${LOCAL_PATH}"
info "Config:      ${RCLONE_CONFIG_FILE}"
info "Transfers:   ${RCLONE_TRANSFERS}"
info "Checkers:    ${RCLONE_CHECKERS}"

if [[ "${RCLONE_DRY_RUN}" == "true" ]]; then
  info "Mode:        DRY RUN"
else
  info "Mode:        SYNC"
fi

START_TIME=$(date +%s)

rclone \
  --config "${RCLONE_CONFIG_FILE}" \
  "${RCLONE_ARGS[@]}"

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

info "Pull completed in ${DURATION}s"
