#!/usr/bin/env bash
set -euo pipefail

THIS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT=$(realpath -m "${THIS_DIR}/..")
CWD="$(pwd)"
trap 'cd "$CWD"' EXIT

ENV_FILE="${ENV_FILE:-env/github/.env}"
IMAGE="${IMAGE:-renovate/renovate:latest}"
NAME="${NAME:-renovate}"
CONFIG_FILE_PATH="${RENOVATE_CONFIG_FILE_PATH:-config/config.js}"
CACHE_HOST_DIR="${RENOVATE_CACHE_HOST_DIR:-./cache/renovate-docker}"
CACHE_HOST_PATH="$REPO_ROOT/${CACHE_HOST_DIR#./}"

EXTRA_ARGS=()

function usage() {
  cat <<'EOF'
Usage:
  run-renovate.sh [options]

Options:
  -e, --env-file PATH        Path to env file (default: .env)
  -i, --image IMAGE          Renovate image (default: renovate/renovate:latest)
  -c, --config FILE          Override config file path (default: RENOVATE_CONFIG_FILE_PATH or config/config.js)
  -d, --dry-run              Set RENOVATE_DRY_RUN=true
  -r, --repository REPO      Add/override RENOVATE_REPOSITORIES
  -p, --platform PLATFORM    Add/override RENOVATE_PLATFORM
  --                        Pass remaining args to docker run
EOF
}

function require_var() {
  local var_name="$1"
  local value="${!var_name:-}"
  
  if [[ -z "$value" ]]; then
    echo "Missing required env var: $var_name" >&2
    exit 1
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -e|--env-file)
      ENV_FILE="$2"
      shift 2
      ;;
    -i|--image)
      IMAGE="$2"
      shift 2
      ;;
    -c|--config)
      CONFIG_FILE_PATH="$2"
      shift 2
      ;;
    -d|--dry-run)
      EXTRA_ARGS+=(-e RENOVATE_DRY_RUN=true)
      shift
      ;;
    -r|--repository)
      EXTRA_ARGS+=(-e "RENOVATE_REPOSITORIES=$2")
      shift 2
      ;;
    -p|--platform)
      EXTRA_ARGS+=(-e "RENOVATE_PLATFORM=$2")
      shift 2
      ;;
    --)
      shift
      EXTRA_ARGS+=("$@")
      break
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[ERROR] Unknown arg: $1" >&2
      usage
      exit 1
      ;;
  esac
done

cd "$REPO_ROOT"
mkdir -p "$CACHE_HOST_PATH"
chmod 777 "$CACHE_HOST_PATH"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

require_var RENOVATE_TOKEN
require_var RENOVATE_REPOSITORIES

if [[ -z "${RENOVATE_CONFIG_FILE_PATH:-}" ]]; then
  RENOVATE_CONFIG_FILE_PATH="$CONFIG_FILE_PATH"
fi

if [[ ! -f "$RENOVATE_CONFIG_FILE_PATH" ]]; then
  echo "[ERROR] Config file not found: $RENOVATE_CONFIG_FILE_PATH" >&2
  exit 1
fi

docker pull "$IMAGE"

RUN_ARGS=(
  run --rm
  --name "$NAME"
  --env-file "$ENV_FILE"
  -e "RENOVATE_BASE_DIR=/tmp/renovate"
  -e "RENOVATE_CACHE_DIR=/tmp/renovate/cache"
  -e "RENOVATE_CONFIG_FILE=/usr/src/app/config.js"
  -v "$REPO_ROOT/$RENOVATE_CONFIG_FILE_PATH:/usr/src/app/config.js:ro"
  -v "$CACHE_HOST_PATH:/tmp/renovate"
)

if [[ -n "${EXTRA_ARGS[*]:-}" ]]; then
  RUN_ARGS+=("${EXTRA_ARGS[@]}")
fi

RUN_ARGS+=("$IMAGE")

exec docker "${RUN_ARGS[@]}"