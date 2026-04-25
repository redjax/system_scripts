#!/usr/bin/env bash
set -euo pipefail

if ! command -v git >&/dev/null; then
  echo "[ERROR] git is not installed" >&2
  exit 1
fi

THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CWD="$(pwd)"
TARGET_REPO="${THIS_DIR}"

function cleanup() {
  cd "${CWD}"
}
trap cleanup EXIT

function usage() {
  echo ""
  echo "Usage: $0 [OPTIONS]"
  echo "Options:"
  echo "  -h, --help    Show this help message"
  echo "  -t, --target  Target repository"
  echo ""
  
  exit 1
}

function parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      -h|--help)
        usage
        exit 0
        shift
        ;;
      -t|--target)
        TARGET_REPO="$2"
        shift 2
        ;;
      *)
        echo "Unknown option: $1"
        usage
        exit 1
        ;;
    esac
  done
}

function repo_summary() {
  echo "[ Repo summary ]"
  echo
  
  git count-objects -vH
  
  echo
}

function commit_count() {
  echo "[ Commit count ]"
  echo

  git rev-list --count --all
  
  echo
}

function top_contributors() {
  echo "[ Top contributors ]"
  echo

  git shortlog -sn --all
  
  echo
}

function top_churn_paths() {
  echo "[ Top churn paths ]"
  echo

  git log --all --numstat --format='' \
    | awk 'NF==3 { add[$3]+=$1; del[$3]+=$2 }
           END { for (f in add) print add[f]+del[f], add[f], del[f], f }' \
    | sort -n | tail -30
  
  echo
}

function largest_blobs() {
  echo "[ Largest blobs ]"
  echo

  git rev-list --objects --all \
    | git cat-file --batch-check='%(objectname) %(objecttype) %(objectsize) %(rest)' \
    | awk '$2=="blob" { print }' \
    | sort -k3 -n | tail -30

  echo
}

function biggest_commits_by_changes() {
  echo "[ Biggest commits by line churn ]"
  echo ""
  
  git log --all --numstat --format='%H %s' \
    | awk '
        /^[0-9a-f]{7,40} / { if (c != "") print total, c; c=$0; total=0; next }
        NF==3 { if ($1 ~ /^[0-9]+$/) total+=$1; if ($2 ~ /^[0-9]+$/) total+=$2 }
        END { if (c != "") print total, c }
      ' \
    | sort -n | tail -30
}

function main() {
  parse_args "$@"

  cd "${TARGET_REPO}"

  repo_summary
  commit_count
  top_contributors
  top_churn_paths
  largest_blobs
  biggest_commits_by_changes
}

main "$@"
