#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

ARGS=(
  --target /
  --recursive
)

case "$(uname -s)" in
  Linux)
    ARGS+=(
      --exclude-dir '^/(proc|sys|dev|run)(/|$)'
    )
    ;;
  Darwin)
    ## Avoid walking the same writable Data volume through its
    #  alternate mount path during a root-directory scan.
    ARGS+=(
      --exclude-dir '^/System/Volumes(/|$)'
    )
    ;;
  *)
    printf 'Unsupported platform.\n' >&2
    exit 2
    ;;
esac

exec /bin/bash "$SCRIPT_DIR/scan.sh" "${ARGS[@]}" "$@"
