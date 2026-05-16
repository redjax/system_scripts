#!/usr/bin/env bash
set -euo pipefail

if ! command -v immich-go >&/dev/null; then
  echo "[ERROR] immich-go is not installed." >&2
  exit 1
fi

IMMICH_URL="${IMMICH_SERVER_URL:-}"
IMMICH_KEY="${IMMICH_KEY:-}"
IMMICH_ADMIN_KEY="${IMMICH_ADMIN_KEY:-}"
PHOTO_DIR="${IMMICH_LOCAL_PHOTOS:-}"
## Trim trailing slashes
PHOTO_DIR="${PHOTO_DIR%/}"

DRY_RUN="false"

function usage() {
  cat <<EOF
Usage: ${0} [OPTIONS]

Options:
  -h, --help        Print this help menu
  -u, --server-url  Immich server URL
  -e, --email       Immich user email
  -k, --api-key     Immich API token
  -K, --admin-key   Immich API token with admin privileges
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
  -K | --admin-key)
    IMMICH_ADMIN_KEY="${2}"
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

cmd=(immich-go upload from-google-photos -s "$IMMICH_URL" -k "$IMMICH_KEY" --on-errors continue)

if [[ -n "${IMMICH_ADMIN_KEY}" ]]; then
  cmd+=(--admin-api-key "${IMMICH_ADMIN_KEY}")
else
  cmd+=(--pause-immich-jobs=FALSE)
fi

## Append photo dir to end of command
cmd+=("$PHOTO_DIR")

if [[ "$DRY_RUN" == "true" ]]; then
  echo "[DRY RUN] Running immich-go in dry-run mode"
  cmd+=(--dry-run)
fi

echo "Starting upload from $PHOTO_DIR to server: $IMMICH_URL"

if ! "${cmd[@]}"; then
  echo "[ERROR] Failed uploading photos" >&2
  exit 1
fi

echo "Upload complete"
