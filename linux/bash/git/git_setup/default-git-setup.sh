#!/usr/bin/env bash
set -euo pipefail

THIS_DEFAULT_SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INIT_SCRIPT="${THIS_DEFAULT_SETUP_DIR}/init-git-setup.sh"

source "${INIT_SCRIPT}"

DEFAULT_ARGS=(
  --default-branch "main"
  --pull-rebase
  --prune-on-fetch
  --auto-setup-remote
  --reuse-conflict
  --editor "${EDITOR:-nvim}"
)

parse_args "${DEFAULT_ARGS[@]}"

if [[ -z "${GIT_USERNAME}" ]]; then
  read -r -p "Git username: " GIT_USERNAME
fi

if [[ -z "${GIT_EMAIL}" ]]; then
  read -r -p "Git email: " GIT_EMAIL
fi

export GIT_USERNAME
export GIT_EMAIL

do_git_setup
