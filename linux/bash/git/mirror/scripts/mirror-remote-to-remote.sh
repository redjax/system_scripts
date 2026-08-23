#!/usr/bin/env bash
set -euo pipefail

SOURCE_URL=""
DEST_URL=""

function usage() {
  cat <<'EOF'
Usage:
  mirror-remote-to-remote.sh <source-url> <destination-url>

Examples:
  mirror-remote-to-remote.sh git@github.com:org/repo.git git@gitlab.com:org/repo.git
  mirror-remote-to-remote.sh https://github.com/org/repo.git https://codeberg.org/org/repo.git
EOF
}

function require_git() {
  if ! command -v git >/dev/null 2>&1; then
    echo "[ERROR] git is required" >&2
    exit 1
  fi
}

function parse_args() {
  [[ $# -eq 2 ]] || {
    usage
    exit 1
  }

  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    usage
    exit 0
  fi

  SOURCE_URL="$1"
  DEST_URL="$2"
}

function main() {
  require_git
  parse_args "$@"

  local tmp_dir mirror_dir
  tmp_dir="$(mktemp -d)"
  mirror_dir="${tmp_dir}/repo.git"

  cleanup() {
    rm -rf "$tmp_dir"
  }
  trap cleanup EXIT

  echo "Creating temporary mirror"
  git clone --mirror "$SOURCE_URL" "$mirror_dir"

  echo "Pushing mirror to destination"
  git -C "$mirror_dir" push --mirror "$DEST_URL"

  echo "Mirror completed"
}

main "$@"