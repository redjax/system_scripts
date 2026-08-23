#!/usr/bin/env bash
set -euo pipefail

THIS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(realpath -m "${THIS_DIR}/..")"
CWD="$(pwd)"
trap 'cd "$CWD"' EXIT

ENV_FILE="${ENV_FILE:-env/github/.env}"
CONFIG_FILE_PATH="${RENOVATE_CONFIG_FILE_PATH:-config/config.js}"
BASE_DIR="${RENOVATE_BASE_DIR:-$REPO_ROOT/cache/renovate}"
RENOVATE_BIN="${RENOVATE_BIN:-}"

function usage() {
  cat <<'EOF'
Usage:
  run-renovate-local.sh [options]

Options:
  -e, --env-file PATH        Path to env file (default: env/github/.env)
  -c, --config FILE          Config file path (default: RENOVATE_CONFIG_FILE_PATH or config/config.js)
  -d, --dry-run              Set RENOVATE_DRY_RUN=true
  -r, --repository REPO      Add/override RENOVATE_REPOSITORIES
  -p, --platform PLATFORM    Add/override RENOVATE_PLATFORM
  --bin PATH                 Force renovate binary path
  --                         Pass remaining args to renovate
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
    -c|--config)
      CONFIG_FILE_PATH="$2"
      shift 2
      ;;
    -d|--dry-run)
      export RENOVATE_DRY_RUN=true
      shift
      ;;
    -r|--repository)
      export RENOVATE_REPOSITORIES="$2"
      shift 2
      ;;
    -p|--platform)
      export RENOVATE_PLATFORM="$2"
      shift 2
      ;;
    --bin)
      RENOVATE_BIN="$2"
      shift 2
      ;;
    --)
      shift
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

mkdir -p "$BASE_DIR"
chmod -R u+rwX "$BASE_DIR"

export RENOVATE_CONFIG_FILE="$REPO_ROOT/$RENOVATE_CONFIG_FILE_PATH"
export RENOVATE_BASE_DIR="$BASE_DIR"
export LOG_LEVEL="${LOG_LEVEL:-info}"

if [[ -z "$RENOVATE_BIN" ]]; then
  if command -v npx >/dev/null 2>&1; then
    RENOVATE_BIN="npx"
  elif command -v renovate >/dev/null 2>&1; then
    RENOVATE_BIN="renovate"
  elif command -v npm >/dev/null 2>&1; then
    echo "Renovate not found; installing with npm..."
    npm install -g renovate
    RENOVATE_BIN="renovate"
  else
    echo "Neither npx, renovate, nor npm found." >&2
    exit 1
  fi
fi

if [[ "$RENOVATE_BIN" == "npx" ]]; then
  exec npx renovate "$@"
else
  exec "$RENOVATE_BIN" "$@"
fi
