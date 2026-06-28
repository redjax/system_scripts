#!/usr/bin/env bash
set -euo pipefail

###########################################################
# Downloads the Ookla speedtest CLI to a temporary path   #
# and executes the binary.                                #
#                                                         #
# The temporary path is removed at the end of the script. #
# If you want to permanently install the CLI, follow      #
# Ookla's instructions (scroll to bottom of page):        #
#   https://www.speedtest.net/apps/cli                    #
###########################################################

## Use an existing installation if available.
if command -v speedtest >/dev/null 2>&1; then
  exec speedtest --accept-license --accept-gdpr "$@"
fi

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
cd "$tmpdir"

## Find latest version & set download URL
DOWNLOAD_URL="$(
  curl -fsSL https://www.speedtest.net/apps/cli |
    grep -oE 'https://install\.speedtest\.net/app/cli/ookla-speedtest-[^"]*-linux-x86_64\.tgz' |
    head -n1
)"

if [[ -z "$DOWNLOAD_URL" ]]; then
  echo "[ERROR] Could not determine the latest Speedtest CLI download URL." >&2
  exit 1
fi

ARCHIVE="${DOWNLOAD_URL##*/}"

## Download & extract archive
curl -fsSLO "$DOWNLOAD_URL"
tar -xf "$ARCHIVE"

exec ./speedtest --accept-license --accept-gdpr "$@"
