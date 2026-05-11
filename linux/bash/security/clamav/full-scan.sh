#!/usr/bin/env bash
set -uo pipefail

##
# ClamAV quick scan
#
# Description:
#   Runs a preset ClamAV scan of the machine. Updates definitions with freshclam.
#
# Scan settings:
#   - Target: "/"
#   - Recursive: true
#   - Log file: ~/clam-quickscan.log
#   - stdout: true
#   - Verbose: true
#
##

if ! command -v clamscan >/dev/null 2>&1; then
    echo "[ERROR] clamscan not found. Install ClamAV first." >&2
    exit 1
fi

THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TARGET="/"
OUTPUT="/tmp/$(date +%Y%m%d-%H%M%S).clamav.log"
RECURSIVE="true"
LOG_FILE="$HOME/clam-quickscan.log"
VERBOSE="true"

function greeting() {
  echo ""
  echo "+==================+"
  echo "| ClamAV Full Scan |"
  echo "+==================+"
  echo ""

  echo "Updates virus definitions & starts a clam scan of /"
  echo "Scan settings:"
  echo "  - Target: $TARGET"
  echo "  - Log file: $LOG_FILE"
  echo ""
  echo "  -----------------  "
  echo ""
}

function freshclam_update() {
    . "${THIS_DIR}/freshclam-update.sh"

    update_clamav_definitions
}

function main() {
    greeting

    freshclam_update
    if [[ $? -ne 0 ]]; then
        echo "[ERROR] Failed to update ClamAV definitions." >&2
        exit 1
    fi

    clamscan -r --stdout --log="$LOG_FILE" "$TARGET"
    if [[ $? -ne 0 ]]; then
        echo "[ERROR] ClamAV scan failed." >&2
        exit 1
    fi
}

if ! main "$@"; then
  echo "[ERROR] ClamAV full scan failed." >&2
  exit 1
fi
