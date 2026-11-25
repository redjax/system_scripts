#!/usr/bin/env bash

set -euo pipefail

## Defaults
REPO_URL=""
QUIET=false

usage() {
  cat << EOF
Usage:
  ${0##*/} [OPTIONS] <repository-url>

Find and display the first commit in a Git repository.

Options:
  -u, --url URL       Git repository URL
  -q, --quiet         Only output the first commit hash
  -h, --help          Display this help menu

Examples:
  ${0##*/} https://github.com/user/repo.git
  ${0##*/} --url https://codeberg.org/user/repo
  ${0##*/} --quiet https://gitlab.com/user/repo.git
  ${0##*/} -u git@github.com:user/repo.git

Supported hosts:
  GitHub, GitLab, Codeberg, Forgejo, Tangled, and any Git-compatible host.
EOF
}

## Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -u | --url)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --url requires a repository URL." >&2
        usage
        exit 1
      fi
      REPO_URL="$2"
      shift 2
      ;;
    -q | --quiet)
      QUIET=true
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    -*)
      echo "Error: Unknown option: $1" >&2
      usage
      exit 1
      ;;
    *)
      if [[ -n "$REPO_URL" ]]; then
        echo "Error: Multiple repository URLs provided." >&2
        usage
        exit 1
      fi
      REPO_URL="$1"
      shift
      ;;
  esac
done

## Validate arguments
if [[ -z "$REPO_URL" ]]; then
  echo "Error: No repository URL provided." >&2
  usage
  exit 1
fi

## Check dependencies
if ! command -v git &> /dev/null; then
  echo "Error: git is not installed." >&2
  exit 1
fi

## Create temporary directory
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

## Clone repository
if ! git clone --quiet --bare "$REPO_URL" "$TMP_DIR/repo.git"; then
  echo "Error: Unable to clone repository." >&2
  exit 1
fi

## Find first commit
FIRST_COMMIT=$(git --git-dir="$TMP_DIR/repo.git" rev-list --max-parents=0 HEAD)

if [[ -z "$FIRST_COMMIT" ]]; then
  echo "Error: No commits found." >&2
  exit 1
fi

## Output
if [[ "$QUIET" == true ]]; then
  printf '%s\n' "$FIRST_COMMIT"
else
  printf 'Root commit(s):\n\n'

  while IFS= read -r commit; do
    git --git-dir="$TMP_DIR/repo.git" show \
      --no-patch --format=fuller "$commit"
    printf '\n'
  done <<< "$FIRST_COMMIT"
fi
