#!/usr/bin/env bash
set -euo pipefail

if ! command -v git >/dev/null 2>&1; then
  echo "[ERROR] git is not installed" >&2
  exit 1
fi

THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CWD="$(pwd)"
TARGET_REPO="${THIS_DIR}"
OUTPUT_FILE=""
RUN_ALL=true
SELECTED_SECTIONS=()

function cleanup() {
  cd "${CWD}"
}
trap cleanup EXIT

function usage() {
  cat <<EOF

Usage: $0 [OPTIONS]

Options:
  -h, --help              Show this help message
  -t, --target <path>     Target repository
  -o, --output <file>     Save report to file
  --all                   Run all sections (default)

  Section selectors (use one or more):
    --repo-summary
    --commit-count
    --top-contributors
    --top-churn-paths
    --largest-blobs
    --biggest-commits

Examples:
  $0
  $0 --target ~/src/myrepo --output report.txt
  $0 --top-contributors --largest-blobs
  $0 --all --output repo-survey.txt

EOF
}

function add_section() {
  RUN_ALL=false
  SELECTED_SECTIONS+=("$1")
}

function parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        usage
        exit 0
        ;;
      -t|--target)
        [[ $# -ge 2 ]] || { echo "[ERROR] Missing value for $1" >&2; exit 1; }
        TARGET_REPO="$2"
        shift 2
        ;;
      -o|--output)
        [[ $# -ge 2 ]] || { echo "[ERROR] Missing value for $1" >&2; exit 1; }
        OUTPUT_FILE="$2"
        shift 2
        ;;
      --all)
        RUN_ALL=true
        SELECTED_SECTIONS=()
        shift
        ;;
      --repo-summary)      add_section "repo_summary"; shift ;;
      --commit-count)      add_section "commit_count"; shift ;;
      --top-contributors)  add_section "top_contributors"; shift ;;
      --top-churn-paths)   add_section "top_churn_paths"; shift ;;
      --largest-blobs)     add_section "largest_blobs"; shift ;;
      --biggest-commits)   add_section "biggest_commits_by_changes"; shift ;;
      *)
        echo "[ERROR] Unknown option: $1" >&2
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
  echo
  git log --all --numstat --format='%H %s' \
    | awk '
        /^[0-9a-f]{7,40} / { if (c != "") print total, c; c=$0; total=0; next }
        NF==3 { if ($1 ~ /^[0-9]+$/) total+=$1; if ($2 ~ /^[0-9]+$/) total+=$2 }
        END { if (c != "") print total, c }
      ' \
    | sort -n | tail -30
  echo
}

function run_section() {
  case "$1" in
    repo_summary) repo_summary ;;
    commit_count) commit_count ;;
    top_contributors) top_contributors ;;
    top_churn_paths) top_churn_paths ;;
    largest_blobs) largest_blobs ;;
    biggest_commits_by_changes) biggest_commits_by_changes ;;
  esac
}

function main() {
  parse_args "$@"
  cd "$TARGET_REPO"

  if [[ "$RUN_ALL" == true ]]; then
    SECTIONS=(
      repo_summary
      commit_count
      top_contributors
      top_churn_paths
      largest_blobs
      biggest_commits_by_changes
    )
  else
    SECTIONS=("${SELECTED_SECTIONS[@]}")
  fi

  if [[ -n "$OUTPUT_FILE" ]]; then
    mkdir -p "$(dirname "$OUTPUT_FILE")"
    {
      for section in "${SECTIONS[@]}"; do
        run_section "$section"
      done
    } | tee "$OUTPUT_FILE"
  else
    for section in "${SECTIONS[@]}"; do
      run_section "$section"
    done
  fi
}

main "$@"
