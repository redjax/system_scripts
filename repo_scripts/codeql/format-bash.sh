#!/usr/bin/env bash
set -euo pipefail

_FORMAT_BASH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_FORMAT_BASH_REPO_ROOT="$(realpath -m "${_FORMAT_BASH_DIR}/../..")"

CWD="$(pwd)"

FORMAT_PATH="${_FORMAT_BASH_REPO_ROOT}"
DRY_RUN="false"
LIST_FILES="false"

if ! command -v shfmt &>/dev/null; then
  echo "[ERROR] shfmt is not installed."
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
  -p, --path <path>     Path to script or directory to format
  -n, --dry-run         Show diff instead of writing changes
  -l, --list-files      List files that will be formatted
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
    -n | --dry-run)
      DRY_RUN="true"
      shift
      ;;
    -l | --list-files)
      LIST_FILES="true"
      shift
      ;;
    *)
      echo "Invalid option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

cd "$_FORMAT_BASH_REPO_ROOT"

## List files that would be formatted
if [[ "$LIST_FILES" == "true" ]]; then
  echo "Would format the following files:"
  echo
  shfmt -l "$FORMAT_PATH"

  exit 0
fi

echo "Formatting bash scripts in:"
echo "  ${FORMAT_PATH}"
echo

## Build shfmt command
SHFMT_CMD=(shfmt)

## Indentation
SHFMT_CMD+=("-i" "2")
## Indent case statements
SHFMT_CMD+=("-ci")

## dry-run mode
if [[ "$DRY_RUN" == "true" ]]; then
  SHFMT_CMD+=("-d")
  echo "[INFO] Dry-run mode enabled (diff only)"

  exit 0
else
  ## write changes
  SHFMT_CMD+=("-w")
fi

find "$FORMAT_PATH" \
  -type f \
  -name "*.sh" \
  -print0 |
  xargs -0 -r "${SHFMT_CMD[@]}"
