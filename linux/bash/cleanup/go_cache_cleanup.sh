#!/usr/bin/env bash
set -euo pipefail

DRY_RUN="false"

usage() {
  cat << EOF
Usage:
  ${0##*/} [OPTIONS]

Options:
  --dry-run   Show what would be cleaned without removing anything
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
      exit 0
      ;;
    *)
      echo "[ERROR] Invalid option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if ! command -v go > /dev/null 2>&1; then
  echo "[ERROR] Go is not installed." >&2
  exit 1
fi

GO_CACHE="$(go env GOCACHE)"

echo "Go build cache: ${GO_CACHE}"

if [[ -d "${GO_CACHE}" ]]; then
  du -sh "${GO_CACHE}"
else
  echo "[WARNING] Go build cache directory does not exist"
  exit 0
fi

if [[ "${DRY_RUN}" == "true" ]]; then
  echo
  echo "[DRY RUN] Would execute: go clean -cache"
  exit 0
fi

echo
echo "Cleaning Go build cache"

if ! go clean -cache 2>&1; then
  echo "[ERROR] Failed to clean Go build cache" >&2
  exit 1
fi

echo
echo "Go build cache cleanup complete"
