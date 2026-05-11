#!/usr/bin/env bash
# set -euo pipefail

_LINT_BASH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_LINT_BASH_REPO_ROOT="$(realpath -m "${_LINT_BASH_DIR}/../..")"

CWD="$(pwd)"

LINT_PATH="${_LINT_BASH_REPO_ROOT}"
LINT_SEV="error"

if ! command -v shellcheck &>/dev/null; then
  echo "[ERROR] shellcheck is not installed."
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
  -p, --path   <path>   Path to script or directory to lint
  --sev-level  <level>  Shellcheck severity level (default: error). Options: info, warning, error
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    -p | --path)
      LINT_PATH="$2"
      LINT_PATH="$(realpath -m "${LINT_PATH}")"
      shift 2
      ;;
    -l|--sev-level)
      LINT_SEV="$2"
      shift 2
      ;;
    *)
      echo "Invalid option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if ! command -v shellcheck >&/dev/null; then
  echo "[ERROR] shellcheck is not installed." >&2
  exit 1
fi

## Lowerscase severity level
LINT_SEV="${LINT_SEV,,}"

if [[ "$LINT_SEV" != "info" &&
      "$LINT_SEV" != "warning" &&
      "$LINT_SEV" != "error" ]]; then
  echo "[ERROR] Invalid severity level: $LINT_SEV" >&2
  echo "        Must be one of: info, warning, error" >&2
  usage
  exit 1
fi

cd "$_LINT_BASH_REPO_ROOT"

echo "Linting bash scripts in:"
echo "  ${LINT_PATH}"
echo

shellcheck_cmd=(shellcheck)
## Add severity level
shellcheck_cmd+=("--severity=$LINT_SEV")
## Add .shellcheckrc file
shellcheck_cmd+=("--rcfile=${_LINT_BASH_REPO_ROOT}/.shellcheckrc")
## Add ability to follow `source some_script.sh`
shellcheck_cmd+=("--external-sources")

find "$LINT_PATH" \
  -type f \
  -name "*.sh" \
  -print0 |
xargs -0 -r "${shellcheck_cmd[@]}"
