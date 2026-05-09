#!/usr/bin/env bash
set -euo pipefail

############################################################
# Script to run my default git setup.                      #
#                                                          #
# Prompts for username/email and sets git config defaults. #
############################################################

## Load git init script
THIS_DEFAULT_SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INIT_SCRIPT="${THIS_DEFAULT_SETUP_DIR}/init-git-setup.sh"

## Load git init script
source "${INIT_SCRIPT}"

## Set default script arguments
DEFAULT_ARGS=(
  --default-branch "main"
  --pull-rebase
  --prune-on-fetch
  --auto-setup-remote
  --reuse-conflict
  --editor "${EDITOR:-nvim}"
)

## Apply defaults
parse_args "${DEFAULT_ARGS[@]}"

## Apply user overrides
parse_args "$@"

## Fill missing required fields
if [[ -z "${GIT_USERNAME}" ]]; then
  read -r -p "Git username: " GIT_USERNAME
fi
if [[ -z "${GIT_EMAIL}" ]]; then
  read -r -p "Git email: " GIT_EMAIL
fi

## Call git setup function
do_git_setup
