#!/usr/bin/env bash
set -euo pipefail

###################################################
# Git Setup                                       #
#                                                 #
# Run this script on a new machine to set up git. #
#                                                 #
# Usage:                                          #
#   ./init-git-setup.sh [OPTIONS]                 #
#                                                 #
# See help with `./init-git-setup.sh --help`      #
###################################################

THIS_DIR_GITSETUP="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"


## Ensure git is installed
if ! command -v git >/dev/null 2>&1; then
  echo "[ERROR] git is not installed. Install git before running this script." >&2
  exit 1
fi

## Default vars
DEFAULT_GITIGNORE_FILE=""
GITLOG_ADVANCED_FORMAT="%C(yellow)%h%C(reset) %C(green)%ar%C(reset) %C(blue)%an%C(reset)%C(auto)%d%C(reset) %s"
GIT_USERNAME=""
GIT_EMAIL=""
GIT_DEFAULT_BRANCH="main"
GIT_ENABLE_PULL_REBASE="false"
GIT_PRUNE_ON_FETCH="false"
GIT_AUTO_SETUP_REMOTE="false"
GIT_REUSE_CONFLICT_RESOLUTION="false"
GIT_ENABLE_SIGNING="false"
GIT_SIGN_SSH_KEY=""
GIT_PREFERRED_EDITOR="${EDITOR:-nvim}"
GIT_GLOBAL_GITIGNORE=""
GIT_PAGER="less -FRX"

#############
# Functions #
#############

## Print help menu
function usage() {
  cat <<EOF
USAGE: $(basename "$0") [OPTIONS]

Options:
  -h, --help               Print this help menu
  -u, --git-user           The username to set for git config user.name (default: none/empty)
  -e, --git-email          The email address to set for git config user.email (default: none/empty)
  -b, --default-branch     The default branch to set for git config init.defaultBranch (default: main)
  -p, --pull-rebase        Enable rebase on pull (default: false)
  -f, --prune-on-fetch     Enable prune on fetch (default: false, usually true)
  -a, --auto-setup-remote  Create remote branches on push (default: false, usually true)
  -r, --reuse-conflict     Reuse conflict resolution (default: false, usually true)
  -s, --enable-signing     Enable SSH signing. When enabled, you must provide a private key (default: false)
  -k, --sign-ssh-key       The private key to use for SSH signing
  -E, --editor             The preferred editor to use (default: Value of \$EDITOR or 'nvim')
  -i, --default-gitignore  Path where .gitignore_global will be created. Subdirectories will use this .gitignore, on top of their own rules (default: none, usually \$HOME/.gitignore_global)

Examples:
  $(basename "$0") -u "John Doe" -e "john@example.com" # Set git config user.name and user.email
  $(basename "$0") -b "main" # Set init.defaultBranch
  $(basename "$0") -p # Enable rebase on pull
  $(basename "$0") -f # Enable prune on fetch
  $(basename "$0") -a # Create remote branches on push
  $(basename "$0") -r # Reuse conflict resolution

Suggested command:

$(basename "$0") \
--git-user "Your Name" \
--git-email "your@email.com" \
--default-branch "main" \
--pull-rebase \
--prune-on-fetch \
--auto-setup-remote \
--reuse-conflict \
--default-gitignore "\$HOME/.gitignore_global" \
--editor "${EDITOR:-vim}"
EOF
}

## Set git command aliases
function set_git_aliases() {
  local advanced_format="$1"

  echo "Setting git aliases"

  git config --global alias.lg "log --graph --oneline --decorate"

  git config --global alias.lga \
    "log --graph --pretty=format:'${advanced_format}' --abbrev-commit"

  git config --global alias.st status
  git config --global alias.co checkout
  git config --global alias.sw switch
  git config --global alias.br branch
  git config --global alias.ci commit
  git config --global alias.last "log -1 HEAD"
  git config --global alias.unstage "restore --staged"
  git config --global alias.graph "log --graph --decorate --oneline --all"
}

## Set git user and email
function set_git_user() {
  local username="$1"
  local email_addr="$2"

  echo "Setting git user to: ${username} <${email_addr}>"

  git config --global user.name "${username}"
  git config --global user.email "${email_addr}"
}

## Set default branch on git repo init
function set_default_branch() {
  local branch="$1"

  echo "Setting default branch to: ${branch}"

  git config --global init.defaultBranch "${branch}"
}

## Enable rebase on pull
function pull_rebase_enabled() {
  local enabled="$1"

  echo "Pull rebase enabled: ${enabled}"

  git config --global pull.rebase "${enabled}"
}

## Enable prune on fetch
function prune_on_fetch_enabled() {
  local enabled="$1"

  echo "Prune on fetch enabled: ${enabled}"

  git config --global fetch.prune "${enabled}"
}

## Create remote branch on push if it doesn't exist
function auto_setup_remote_enabled() {
  local enabled="$1"

  echo "Create remote branch on push enabled: ${enabled}"

  git config --global push.autoSetupRemote "${enabled}"
}

## Reuse conflict resolution commits in future merges/rebases
function reuse_conflict_resolution_enabled() {
  local enabled="$1"

  echo "Reuse conflict resolution enabled: ${enabled}"

  git config --global rerere.enabled "${enabled}"
}

## Enable git color output
function enable_color() {
  echo "Set git color output to auto"

  git config --global color.ui auto
}

## Set git pager
function set_pager() {
  local pager="${1:-less -FRX}"

  echo "Setting git pager to: ${pager}"

  git config --global core.pager "${pager}"
}

## Configure SSH signing of commits
function enable_signing() {
  local signing_enabled="$1"
  local private_key="$2"

  echo "SSH signing enabled: ${signing_enabled}"

  if [[ "${signing_enabled}" != "true" ]]; then
    return
  fi

  if [[ -z "${private_key}" ]]; then
    echo "[ERROR] Private key not provided for SSH signing"
    return 1
  fi

  echo "Enabling SSH signing with key: ${private_key}"

  git config --global gpg.format ssh
  git config --global user.signingkey "${private_key}"
  git config --global commit.gpgsign true
}

## Set git line endings
function set_line_endings() {
  echo "Setting git line endings to: input"

  git config --global core.autocrlf input
}

## Set git editor
function set_editor() {
  local editor="$1"
  local editor_bin

  editor_bin="$(awk '{print $1}' <<< "$editor")"

  ## Test if editor exists, fallback through common editors
  if ! command -v "${editor_bin}" &>/dev/null; then
    echo "[WARNING] Editor not found: ${editor}"

    if command -v nvim &>/dev/null; then
      editor="nvim"
    elif command -v vim &>/dev/null; then
      editor="vim"
    elif command -v nano &>/dev/null; then
      editor="nano"
    else
      echo "[ERROR] Could not determine a usable editor"
      return 1
    fi
  fi

  echo "Setting git editor to: ${editor}"

  git config --global core.editor "${editor}"
}

## Set global gitignore file
function set_global_gitignore() {
  local gitignore_path="$1"

  if [[ ! -f "${gitignore_path}" ]]; then
    if [[ -f "${DEFAULT_GITIGNORE_FILE}" ]]; then
      echo "Creating global gitignore at path: ${gitignore_path}"
      cp "${DEFAULT_GITIGNORE_FILE}" "${gitignore_path}"
    else
      echo "[WARNING] Could not find default global gitignore at path: ${DEFAULT_GITIGNORE_FILE}"
      return
    fi
  fi

  git config --global core.excludesfile "${gitignore_path}"
}

## Set merge conflict style
function set_conflict_style() {
  local style="${1:-zdiff3}"

  echo "Setting merge conflict style to: ${style}"

  git config --global merge.conflictstyle "${style}"
}

## Enable misspelled git command autocorrection
function set_autocorrect() {
  local mode="${1:-prompt}"

  echo "Setting git help.autocorrect to: ${mode}"

  git config --global help.autocorrect "${mode}"
}

## Parse CLI args
function parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -u|--git-user)
        [[ $# -lt 2 ]] && { echo "[ERROR] Missing value for $1"; exit 1; }
        GIT_USERNAME="$2"
        shift 2
        ;;
      -e|--git-email)
        [[ $# -lt 2 ]] && { echo "[ERROR] Missing value for $1"; exit 1; }
        GIT_EMAIL="$2"
        shift 2
        ;;
      -b|--default-branch)
        [[ $# -lt 2 ]] && { echo "[ERROR] Missing value for $1"; exit 1; }
        GIT_DEFAULT_BRANCH="$2"
        shift 2
        ;;
      -p|--pull-rebase)
        GIT_ENABLE_PULL_REBASE="true"
        shift
        ;;
      -f|--prune-on-fetch)
        GIT_PRUNE_ON_FETCH="true"
        shift
        ;;
      -a|--auto-setup-remote)
        GIT_AUTO_SETUP_REMOTE="true"
        shift
        ;;
      -r|--reuse-conflict)
        GIT_REUSE_CONFLICT_RESOLUTION="true"
        shift
        ;;
      -s|--enable-signing)
        GIT_ENABLE_SIGNING="true"
        shift
        ;;
      -k|--sign-ssh-key)
        [[ $# -lt 2 ]] && { echo "[ERROR] Missing value for $1"; exit 1; }
        GIT_SIGN_SSH_KEY="$2"
        shift 2
        ;;
      -E|--editor)
        [[ $# -lt 2 ]] && { echo "[ERROR] Missing value for $1"; exit 1; }
        GIT_PREFERRED_EDITOR="$2"
        shift 2
        ;;
      -i|--default-gitignore)
        [[ $# -lt 2 ]] && { echo "[ERROR] Missing value for $1"; exit 1; }
        GIT_GLOBAL_GITIGNORE="$2"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "[ERROR] Invalid arg: $1"
        exit 1
        ;;
    esac
  done
}

## Main orchestration function
function do_git_setup() {
  set_git_aliases "${GITLOG_ADVANCED_FORMAT}"
  echo

  set_default_branch "${GIT_DEFAULT_BRANCH}"
  echo

  pull_rebase_enabled "${GIT_ENABLE_PULL_REBASE}"
  echo

  prune_on_fetch_enabled "${GIT_PRUNE_ON_FETCH}"
  echo

  auto_setup_remote_enabled "${GIT_AUTO_SETUP_REMOTE}"
  echo

  reuse_conflict_resolution_enabled "${GIT_REUSE_CONFLICT_RESOLUTION}"
  echo

  enable_color
  echo

  set_pager "${GIT_PAGER}"
  echo

  enable_signing "${GIT_ENABLE_SIGNING}" "${GIT_SIGN_SSH_KEY}"
  echo

  set_line_endings
  echo

  set_editor "${GIT_PREFERRED_EDITOR}"
  echo

  set_conflict_style
  echo

  set_autocorrect
  echo

  if [[ -n "${GIT_GLOBAL_GITIGNORE}" ]]; then
    set_global_gitignore "${GIT_GLOBAL_GITIGNORE}"
    echo
  fi

  if [[ -n "${GIT_USERNAME}" && -n "${GIT_EMAIL}" ]]; then
    set_git_user "${GIT_USERNAME}" "${GIT_EMAIL}"
  else
    echo "[INFO] Git username/email not provided. Skipping git user config."
  fi

  echo "Setup complete."
}

## Entrypoint
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  parse_args "$@"
  do_git_setup
fi
