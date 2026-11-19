#!/usr/bin/env bash
set -euo pipefail

############################################################################
# Prunes a target Git repository's local branches                          #
#                                                                          #
# Deletes local branches that have been merged in the remote and deleted.  #
# The script only deletes branches when --apply is passed. Run the script  #
# without --apply to see what would be removed.                            #
#                                                                          #
# This script is risky to use; if the git algorithm detects a local branch #
# as a deletion candidate but you are not done working on it, there is no  #
# mechanism to skip that branch. Always run without --apply first to see   #
# what the script will do before committing.                               #
############################################################################

TARGET_REPO=""
APPLY="false"
DEFAULT_BRANCH="main"
FETCH_ALL="true"

usage() {
  cat << EOF
Usage:
  ${0##*/} --target-repo DIRECTORY [OPTIONS]

Prune stale remote-tracking refs and optionally delete local branches whose
tracked upstream branch no longer exists.

This is designed for squash-merge workflows where git branch -d may reject
already-integrated branches because their original commits are not ancestors
of the default branch.

Options:
  -t, --target-repo     DIRECTORY  Target Git repository directory (required)
  -a, --apply                      Delete listed local branches
  -b, --default-branch  NAME       Branch to switch to before cleanup (default: main)
      --origin-only                Prune only origin instead of all remotes
  -h, --help                       Print this help menu

Examples:
  ${0##*/} --target-repo /path/to/repository
  ${0##*/} --target-repo /path/to/repository --apply
  ${0##*/} -t ~/git/repos/blog -b main --apply
EOF
}

errexit() {
  echo "[ERROR] $*" >&2
  exit 1
}

info() {
  echo "[INFO] $*"
}

warn() {
  echo "[WARN] $*" >&2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -t | --target-repo)
      [[ $# -ge 2 ]] || errexit "$1 requires a directory argument"
      [[ -n "$2" ]] || errexit "$1 requires a non-empty directory argument"

      TARGET_REPO="$(realpath -m "$2")"
      shift 2
      ;;
    -a | --apply)
      APPLY="true"
      shift
      ;;
    -b | --default-branch)
      [[ $# -ge 2 ]] || errexit "$1 requires a branch name"
      [[ -n "$2" ]] || errexit "$1 requires a non-empty branch name"

      DEFAULT_BRANCH="$2"
      shift 2
      ;;
    --origin-only)
      FETCH_ALL="false"
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      errexit "Invalid option: $1"
      ;;
  esac
done

[[ -n "${TARGET_REPO}" ]] || errexit "--target-repo DIRECTORY is required"
[[ -d "${TARGET_REPO}" ]] || errexit "Target repository directory does not exist: ${TARGET_REPO}"

if ! git -C "${TARGET_REPO}" rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  errexit "Target is not inside a Git work tree: ${TARGET_REPO}"
fi

REPO_ROOT="$(git -C "${TARGET_REPO}" rev-parse --show-toplevel)"

if ! git -C "${REPO_ROOT}" show-ref --verify --quiet "refs/heads/${DEFAULT_BRANCH}"; then
  errexit "Default branch does not exist locally: ${DEFAULT_BRANCH}"
fi

if [[ -n "$(git -C "${REPO_ROOT}" status --porcelain)" ]]; then
  errexit "Working tree has uncommitted changes: ${REPO_ROOT}"
fi

CURRENT_BRANCH="$(git -C "${REPO_ROOT}" branch --show-current)"

if [[ -z "${CURRENT_BRANCH}" ]]; then
  errexit "Repository is in detached HEAD state: ${REPO_ROOT}"
fi

info "Repository: ${REPO_ROOT}"
info "Current branch: ${CURRENT_BRANCH}"
info "Default branch: ${DEFAULT_BRANCH}"

if [[ "${CURRENT_BRANCH}" != "${DEFAULT_BRANCH}" ]]; then
  info "Switching to ${DEFAULT_BRANCH}"

  if ! git -C "${REPO_ROOT}" switch "${DEFAULT_BRANCH}"; then
    errexit "Unable to switch to ${DEFAULT_BRANCH}"
  fi
fi

info "Updating ${DEFAULT_BRANCH}"

if ! git -C "${REPO_ROOT}" pull --ff-only; then
  errexit "Unable to fast-forward ${DEFAULT_BRANCH}; resolve it before pruning branches"
fi

if [[ "${FETCH_ALL}" == "true" ]]; then
  info "Fetching all remotes and pruning stale remote-tracking refs"
  git -C "${REPO_ROOT}" fetch --all --prune
else
  info "Fetching origin and pruning stale remote-tracking refs"
  git -C "${REPO_ROOT}" fetch origin --prune
fi

STALE_BRANCHES=()

while IFS= read -r branch; do
  [[ -n "${branch}" ]] && STALE_BRANCHES+=("${branch}")
done < <(
  git -C "${REPO_ROOT}" branch -vv |
    awk '/: gone]/{print $1}'
)

echo

if [[ "${#STALE_BRANCHES[@]}" -eq 0 ]]; then
  info "No local branches with deleted upstreams were found."
  exit 0
fi

info "Found ${#STALE_BRANCHES[@]} local branch(es) with deleted upstreams:"

for branch in "${STALE_BRANCHES[@]}"; do
  echo "  ${branch}"
done

if [[ "${APPLY}" != "true" ]]; then
  echo
  warn "Preview only. No local branches were deleted."
  info "Review the list, then rerun with --apply to delete these local branches."
  exit 0
fi

echo
info "Deleting local branches with deleted upstreams"

for branch in "${STALE_BRANCHES[@]}"; do
  info "Deleting ${branch}"
  git -C "${REPO_ROOT}" branch -D -- "${branch}"
done

echo
info "Finished pruning local branches."
