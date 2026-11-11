#!/usr/bin/env bash
set -euo pipefail

if ! command -v brew > /dev/null 2>&1; then
  echo "[ERROR] Homebrew is not installed" >&2
  exit 1
fi

DRY_RUN="false"

usage() {
  cat << EOF
Usage:
  ${0##*/} [OPTIONS]

Options:
  --dry-run   Do a cleanup dry-run without removing any files
  -h, --help  Print this help menu
EOF
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run)
      DRY_RUN="true"
      shift
      ;;
    -h | --help)
      usage
      exit 1
      ;;
    *)
      echo "[ERROR] Invalid option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

brew_opts=(--prune=all)

if [[ "${DRY_RUN}" == "true" ]]; then
  brew_opts+=(--dry-run)
fi

echo "Running Homebrew's cleanup"
if ! brew cleanup "${brew_opts[@]}" 2>&1; then
  echo "[ERROR] Failed during Homebrew's cleanup" >&2
  exit 1
fi

echo
echo "Homebrew cleanup complete"
