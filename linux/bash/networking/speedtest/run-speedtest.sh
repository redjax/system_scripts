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

## Detect CPU architecture
arch="$(uname -m)"

case "$arch" in
  x86_64)
    ookla_arch="x86_64"
    ;;
  aarch64 | arm64)
    ookla_arch="aarch64"
    ;;
  armv7l | armv7*)
    ookla_arch="armhf"
    ;;
  *)
    echo "[ERROR] Unsupported architecture: $arch" >&2
    exit 1
    ;;
esac

## Set platform OS
#  TODO: Add macOS support
os="linux"

## Get latest version string
version="$(
  curl -fsSL https://www.speedtest.net/apps/cli |
    grep -oE 'ookla-speedtest-[0-9]+\.[0-9]+\.[0-9]+' |
    head -n1 |
    sed 's/ookla-speedtest-//'
)"

DOWNLOAD_URL="https://install.speedtest.net/app/cli/ookla-speedtest-${version}-${os}-${ookla_arch}.tgz"

if [[ -z "$DOWNLOAD_URL" ]]; then
  echo "[ERROR] Could not determine the latest Speedtest CLI download URL." >&2
  exit 1
fi

ARCHIVE="${DOWNLOAD_URL##*/}"

## Download & extract archive
curl -fsSLO "$DOWNLOAD_URL"
tar -xf "$ARCHIVE"

exec ./speedtest --accept-license --accept-gdpr "$@"
