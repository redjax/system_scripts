#!/usr/bin/env bash

_LINT_PYTHON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_LINT_PYTHON_REPO_ROOT="$(realpath -m "${_LINT_PYTHON_DIR}/../..")"

CWD="$(pwd)"

RUFF_CMD=""
LINT_PATH="${_LINT_PYTHON_REPO_ROOT}"
FIX="false"

if command -v ruff >&/dev/null; then
  RUFF_CMD="ruff"
elif command -v uvx >&/dev/null; then
  RUFF_CMD="uvx ruff"
else
  echo "[ERROR] Ruff is not installed." >&2
  exit 1
fi

function cleanup() {
  cd "$CWD"
}
trap cleanup EXIT

function usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Options:
  -h, --help         Show this help message
  --fix              Attempt to fix issues
  -p, --path <path>  Path to the Python project directory or script to check/fix. Leave empty for entire repository
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    --fix)
      FIX="true"
      shift
      ;;
    -p | --path)
      LINT_PATH="$2"
      LINT_PATH="$(realpath -m "${LINT_PATH}")"
      shift 2
      ;;
    *)
      echo "Invalid option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

cd "$_LINT_PYTHON_REPO_ROOT"

if [[ "$FIX" == "true" ]]; then
  RUFF_CMD="$RUFF_CMD check ${LINT_PATH} --fix"
  echo "Fixing Python issues with ruff"
else
  RUFF_CMD="$RUFF_CMD check ${LINT_PATH}"
fi

eval "$RUFF_CMD"
LAST_EXIT=$?

if [[ "${FIX}" == "false" ]]; then
  echo
  echo "Review results above. When you are ready to fix, run:"
  echo "  $0 --fix"
fi
