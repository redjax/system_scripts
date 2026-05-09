#!/usr/bin/env bash
set -euo pipefail

########################################
# Bump Python requirements with uv and #
# export to requirements.txt.          #
########################################

if ! command -v uv >/dev/null 2>&1; then
  echo "[ERROR] uv is not installed" >&2
  exit 1
fi

THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT=$(realpath -m "$THIS_DIR/../../..")
CWD="$(pwd)"

DRY_RUN="false"

PY_PROJECT_DIR=""
COMPILE_REQUIREMENTS_TXT="false"
REQUIREMENTS_FILE="requirements.txt"

function cleanup() {
  cd "${CWD}"
}
trap cleanup EXIT

function usage() {
  cat <<EOF

Usage: $0 [OPTIONS]

Options:
  -h, --help              Show this help message
  --dry-run               Describe actions script would take, without taking them
  -p, --project-dir       Path to the Python project directory
EOF
}

while [[ $# -gt 0 ]]; do
  case $1 in
    -h | --help)
      usage
      exit 0
      ;;
    -p|--project-dir)
      PY_PROJECT_DIR="$2"
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

function export_requirements_txt() {
  local requirements_file="$1"

  echo "(Re)compiling requirements.txt with uv"
  echo "Output: ${requirements_file}"
  
  if [[ "${DRY_RUN}" == "true" ]]; then
    echo "[DRY RUN] Would run: uv pip compile requirements.txt -o ${requirements_file} --upgrade"
    echo "[DRY RUN] Would run: uv pip sync requirements.txt"
  else
    uv pip compile requirements.txt -o "${requirements_file}" --upgrade
    uv pip sync requirements.txt
  fi
}

if [[ -z "${PY_PROJECT_DIR}" ]]; then
  echo "[ERROR] --project-dir is required" >&2

  usage
  exit 1
fi

if [[ ! -d "${PY_PROJECT_DIR}" ]]; then
  echo "[ERROR] Could not find Python project dir: ${PY_PROJECT_DIR}" >&2
  exit 1
fi

if [[ "${DRY_RUN}" == "true" ]]; then
  echo "[DRY RUN] Would cd to ${PY_PROJECT_DIR}"
else
  cd "$PY_PROJECT_DIR"
fi

export_requirements_txt "${REQUIREMENTS_FILE}"
