#!/usr/bin/env bash
set -euo pipefail

_FORMAT_PYTHON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_FORMAT_PYTHON_REPO_ROOT="$(realpath -m "${_FORMAT_PYTHON_DIR}/../..")"

CWD="$(pwd)"

FORMAT_PATH="${_FORMAT_PYTHON_REPO_ROOT}"
DRY_RUN="false"

RUFF_CMD=""

if command -v ruff &>/dev/null; then
  RUFF_CMD="ruff"
elif command -v uvx &>/dev/null; then
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
  -h, --help            Show this help message
  -p, --path <path>     Path to Python file or directory to format
  --dry-run             Show diff instead of applying formatting
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    -p | --path)
      FORMAT_PATH="$2"
      FORMAT_PATH="$(realpath -m "${FORMAT_PATH}")"
      shift 2
      ;;
    --dry-run)
      DRY_RUN="true"
      shift
      ;;
    *)
      echo "Invalid option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

cd "$_FORMAT_PYTHON_REPO_ROOT"

echo "Formatting Python files in:"
echo "  ${FORMAT_PATH}"
echo

RUFF_ARGS=(format "$FORMAT_PATH")

if [[ "$DRY_RUN" == "true" ]]; then
  echo "[INFO] Dry-run mode enabled (no changes applied)"
  RUFF_ARGS+=(--check)
fi

echo "Formatting Python scripts with ruff"
$RUFF_CMD "${RUFF_ARGS[@]}"
