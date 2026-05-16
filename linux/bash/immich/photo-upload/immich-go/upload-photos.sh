#!/usr/bin/env bash
set -euo pipefail

if ! command -v immich-go >&/dev/null; then
  echo "[ERROR] immich-go is not installed." >&2
  exit 1
fi

IMMICH_URL="${IMMICH_SERVER_URL:-}"
IMMICH_KEY="${IMMICH_KEY:-}"
PHOTO_DIR="${IMMICH_LOCAL_PHOTOS:-}"

DRY_RUN="false"

function usage() {
  cat <<EOF
Usage: ${0} [OPTIONS]

Options:
  -h, --help        Print this help menu
  -u, --server-url  Immich server URL
  -e, --email       Immich user email
  -k, --api-key     Immich API token
  -p, --local-path  Path to local photos directory
  --dry-run         Describe actions without taking them
EOF
}

## Parse CLI arguments
while [[ $# -gt 0 ]]; do
  case $1 in
  -h | --help)
    usage
    exit 0
    ;;
  -u | --server-url)
    IMMICH_URL="${2}"
    shift 2
    ;;
  -e | --email)
    IMMICH_EMAIL="${2}"
    shift 2
    ;;
  -k | --api-key)
    IMMICH_KEY="${2}"
    shift 2
    ;;
  -p | --local-path)
    PHOTO_DIR="${2}"
    shift 2
    ;;
  --dry-run)
    DRY_RUN="true"
    shift
    ;;
  *)
    echo "[ERROR] Invalid arg: $1" >&2
    usage
    exit 1
    ;;
  esac
done

## Validate inputs
[[ -z "${IMMICH_URL}" ]] && echo "[ERROR] Missing --server-url" >&2 && usage && exit 1
[[ -z "${IMMICH_KEY}" ]] && echo "[ERROR] Missing --api-key" >&2 && usage && exit 1
[[ -z "${PHOTO_DIR}" ]] && echo "[ERROR] Missing --local-path" >&2 && usage && exit 1

if [[ ! -d "${PHOTO_DIR}" ]]; then
  echo "[ERROR] Could not find local photos dir: ${PHOTO_DIR}" >&2
  exit 1
fi

if [[ "$DRY_RUN" == "true" ]]; then
  echo "[DRY RUN] Would authenticate to server: ${IMMICH_URL}"
  echo "[DRY RUN] Would upload photos from: ${PHOTO_DIR}"
else
  ## Upload photos recursively
  echo "Starting upload from $PHOTO_DIR to server: ${IMMICH_URL}"

  if ! immich-go upload from-folder -s "$IMMICH_URL" -k "$IMMICH_KEY" --pause-immich-jobs=FALSE --on-errors continue "$PHOTO_DIR" 2>&1; then
    echo "[ERROR] Failed uploading photos" >&2
    exit 1
  fi

  echo "Upload complete"
fi
