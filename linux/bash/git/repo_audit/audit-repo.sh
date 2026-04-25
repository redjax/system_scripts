#!/usr/bin/env bash
set -euo pipefail

if ! command -v git >/dev/null 2>&1; then
  echo "[ERROR] git is not installed" >&2
  exit 1
fi

## Default args
THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CWD="$(pwd)"
TARGET_REPO="${THIS_DIR}"
OUTPUT_FILE=""
RUN_ALL=true
SELECTED_SECTIONS=()

## Function to run on exit
function cleanup() {
  cd "${CWD}"
}
trap cleanup EXIT

## Print help menu
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
  --contributors
  --author-churn
  --top-churn-paths
  --largest-blobs
  --biggest-commits

Aliases:
  --top-contributors      Alias for --contributors

Examples:
  $0
  $0 --target ~/src/myrepo --output report.txt
  $0 --contributors --largest-blobs
  $0 --all --output repo-survey.txt

EOF
}

## Add a section to the list based on args
function add_section() {
  RUN_ALL=false
  SELECTED_SECTIONS+=("$1")
}

## Parse CLI args
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
      --contributors)      add_section "contributors"; shift ;;
      --top-contributors)  add_section "contributors"; shift ;;
      --author-churn)      add_section "author_churn"; shift ;;
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

## Ensure target repo is a git repo
function ensure_repo() {
  if ! git -C "$TARGET_REPO" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "[ERROR] Not a git repository: $TARGET_REPO" >&2
    exit 1
  fi
}

## Get an overview/summary of the repository
function repo_summary() {
  echo "[ Repo summary ]"
  echo
  git count-objects -vH
  echo
}

## Count the number of commits
function commit_count() {
  echo "[ Commit count ]"
  echo
  git rev-list --count --all
  echo
}

## List contributors
function contributors() {
  echo "[ Contributors ]"
  echo
  git shortlog -sne --all
  echo
}

## List author churn, which is a measure of
#  how many lines have been added and removed
#  per author
function author_churn() {
  echo "[ Author churn ]"
  echo
  git log --all --numstat --format='%aN <%aE>' \
    | awk '
        /^.+ <.+>$/ { author=$0; next }
        NF==3 {
          if ($1 ~ /^[0-9]+$/) add[author]+=$1
          if ($2 ~ /^[0-9]+$/) del[author]+=$2
        }
        END {
          for (a in add) print add[a]+del[a], add[a], del[a], a
        }
      ' \
    | sort -n | tail -30
  echo
}

## List the top 30 most churned paths
function top_churn_paths() {
  echo "[ Top churn paths ]"
  echo
  git log --all --numstat --format='' \
    | awk 'NF==3 { add[$3]+=$1; del[$3]+=$2 }
           END { for (f in add) print add[f]+del[f], add[f], del[f], f }' \
    | sort -n | tail -30
  echo
}

## List the largest blobs
function largest_blobs() {
  echo "[ Largest blobs ]"
  echo
  git rev-list --objects --all \
    | git cat-file --batch-check='%(objectname) %(objecttype) %(objectsize) %(rest)' \
    | awk '$2=="blob" { print }' \
    | sort -k3 -n | tail -30
  echo
}

## List the biggest commits by number of changes
function biggest_commits_by_changes() {
  echo "[ Biggest commits by line churn ]"
  echo
  git log --all --numstat --format='%H %s' \
    | awk '
        /^[0-9a-f]{7,40} / {
          if (commit != "") print total, commit
          commit=$0
          total=0
          next
        }
        NF==3 {
          if ($1 ~ /^[0-9]+$/) total+=$1
          if ($2 ~ /^[0-9]+$/) total+=$2
        }
        END {
          if (commit != "") print total, commit
        }
      ' \
    | sort -n | tail -30
  echo
}

## Run a section
function run_section() {
  case "$1" in
    repo_summary) repo_summary ;;
    commit_count) commit_count ;;
    contributors) contributors ;;
    author_churn) author_churn ;;
    top_churn_paths) top_churn_paths ;;
    largest_blobs) largest_blobs ;;
    biggest_commits_by_changes) biggest_commits_by_changes ;;
  esac
}

## --------------------------------------------------------------------------

function main() {
  parse_args "$@"
  ensure_repo
  cd "$TARGET_REPO"

  if [[ "$RUN_ALL" == true ]]; then
    SECTIONS=(
      repo_summary
      commit_count
      contributors
      author_churn
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

if ! main "$@" >&2; then
  echo "[ERROR] Failed analyzing git repository" >&2
  exit 1
fi
