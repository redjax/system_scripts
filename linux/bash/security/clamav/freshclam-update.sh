#!/usr/bin/env bash
set -uo pipefail

##
# Update ClamAV virus definitions
##

function update_clamav_definitions() {
    if ! command -v freshclam >/dev/null 2>&1; then
        echo "[ERROR] freshclam not found. Install ClamAV first." >&2
        return 1
    fi

    echo "Updating virus definitions"
    sudo freshclam -v
    if [[ $? -ne 0 ]]; then
        echo "[ERROR] Failed to update ClamAV definitions." >&2
        return 1
    fi

    echo ""
    echo "ClamAV definitions updated."
    echo ""
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if ! update_clamav_definitions "$@"; then
        echo "[ERROR] Failed to update ClamAV definitions." >&2
        exit 1
    fi
fi
