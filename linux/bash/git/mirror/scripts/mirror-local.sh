#!/usr/bin/env bash
set -euo pipefail

SOURCE_URL=""
LOCAL_ROOT="./repos"

function usage() {
  cat <<'EOF'
Usage:
  mirror-local.sh <source-url> [--local-root <dir>]

Examples:
  mirror-local.sh git@github.com:org/repo.git
  mirror-local.sh https://github.com/org/repo.git --local-root /data/mirrors
EOF
}

function require_git() {
  if ! command -v git >/dev/null 2>&1; then
    echo "[ERROR] git is required" >&2
    exit 1
  fi
}

function require_arg() {
  local flag="$1"
  local value="${2:-}"
  if [[ -z "$value" || "$value" == --* ]]; then
    echo "[ERROR] missing value for ${flag}" >&2
    exit 2
  fi
}

function parse_repo_path() {
  local url="$1"
  local path

  path="$(printf '%s' "$url" | sed -E 's#^[a-zA-Z][a-zA-Z0-9+.-]*://[^/]+/##; s#^[^@]+@[^:]+:##; s#^file://##; s#^/##')"

  if [[ -z "$path" || "$path" == "$url" ]]; then
    path="$(basename "$url")"
  fi

  path="${path%.git}"
  printf '%s' "$path"
}

function parse_args() {
  [[ $# -gt 0 ]] || {
    usage
    exit 1
  }

  while [[ $# -gt 0 ]]; do
    case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --local-root)
      require_arg "--local-root" "${2:-}"
      LOCAL_ROOT="$2"
      shift 2
      ;;
    --*)
      echo "[ERROR] unknown flag: $1" >&2
      usage
      exit 2
      ;;
    *)
      if [[ -z "$SOURCE_URL" ]]; then
        SOURCE_URL="$1"
        shift
      else
        echo "[ERROR] unexpected argument: $1" >&2
        usage
        exit 2
      fi
      ;;
    esac
  done

  if [[ -z "$SOURCE_URL" ]]; then
    echo "[ERROR] source URL is required" >&2
    usage
    exit 1
  fi
}

function main() {
  require_git
  parse_args "$@"

  local repo_path mirror_path
  repo_path="$(parse_repo_path "$SOURCE_URL")"
  mirror_path="${LOCAL_ROOT}/${repo_path}.git"

  mkdir -p "$(dirname "$mirror_path")"

  if [[ -d "$mirror_path" ]]; then
    echo "Updating mirror: ${mirror_path}"
    git -C "$mirror_path" remote update --prune
  else
    echo "Creating mirror: ${mirror_path}"
    git clone --mirror "$SOURCE_URL" "$mirror_path"
  fi

  echo "Mirror ready: ${mirror_path}"
}

main "$@"