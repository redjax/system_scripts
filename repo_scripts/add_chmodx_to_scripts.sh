#!/usr/bin/env bash

set -uo pipefail

THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT=$(realpath -m "$THIS_DIR/..")
LINUX_SCRIPTS_DIR="${REPO_ROOT}/linux"

DRY_RUN=false

function usage() {
    echo ""
    echo "Usage: ${0} [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --dry-run  Describe actions that would be taken, without taking them."
    echo "  -h|--help  Print help menu"
    echo ""
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            usage

            exit 0
            ;;
        *)
            echo "[ERROR] Invalid options: $1"

            usage
            exit 1
            ;;
    esac
done

echo "Searching for .sh files that do not have chmod +x set."
echo "  Search path: '${LINUX_SCRIPTS_DIR}'"

if [ "$DRY_RUN" = true ]; then
    echo "  DRY RUN enabled"
fi

echo ""
echo "Search results:"

find ~/scripts/system_scripts/linux -type f -name "*.sh" ! -executable | while IFS= read -r file; do
  if [ "$DRY_RUN" = true ]; then
    echo "  Script: $file"
  else
    echo "  Adding chmod +x to: $file"
    chmod +x "$file"
  fi
done

if [ "$DRY_RUN" = true ]; then
    echo ""

    echo "Re-run the script without --dry-run to make these files executable."
fi
