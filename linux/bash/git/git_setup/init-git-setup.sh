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
# See help with ./init-git-setup.sh --help        #
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
GENERATE_GLOBAL_GITIGNORE=""
GIT_PAGER="less -FRX"

## Default gitignore contents
DEFAULT_GITIGNORE_CONTENT=$(cat <<'EOF'
############################################################
# Global gitignore                                         #
#                                                          #
# Patterns in this file apply to all repositories          #
# in the current directory tree (this path & all subdirs). #
#                                                          #
# See https://git-scm.com/docs/gitignore                   #
############################################################

## Junk files
*.swp
*.swo

## OS-specific junk files
.DS_Store
Thumbs.db
ehthumbs.db

## Temporary files
.netrwhist
*.tmp
*.tmp.*
*.bak
*.bak.*
*.old
*.old.*
*.orig
*.orig.*

## Log files
*.log
*.log.*

## Cache files
*.cache
*.cache.*

## Temporary directories
tmp/
temp/
temp.*
tmp.*

## Database files
*.sqlite
*.sqlite3
*.db
*.db3
*.db-wal
*.db-shm
*.db-wal-journal

## Secrets
.env
.env.*
*.local
*.local.*
*.secret
*.secret.*

## Node.js
node_modules

## Python
__pycache__
*.py[cod]
EOF
)

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
  $(basename "$0") -u "John Doe" -e "john@example.com"
  $(basename "$0") -b "main"
  $(basename "$0") -p
  $(basename "$0") -f
  $(basename "$0") -a
  $(basename "$0") -r

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
  git config --global user.name "$1"
  git config --global user.email "$2"
}

## Set default branch on git repo init
function set_default_branch() {
  git config --global init.defaultBranch "$1"
}

## Enable rebase on pull
function pull_rebase_enabled() {
  git config --global pull.rebase "$1"
}

## Enable prune on fetch
function prune_on_fetch_enabled() {
  git config --global fetch.prune "$1"
}

## Create remote branch on push if it doesn't exist
function auto_setup_remote_enabled() {
  git config --global push.autoSetupRemote "$1"
}

## Reuse conflict resolution commits in future merges/rebases
function reuse_conflict_resolution_enabled() {
  git config --global rerere.enabled "$1"
}

## Enable git color output
function enable_color() {
  echo "Set git color output to auto"

  git config --global color.ui auto
}

## Set git pager
function set_pager() {
  git config --global core.pager "${1:-less -FRX}"
}

## Configure SSH signing of commits
function enable_signing() {
  [[ "$1" != "true" ]] && return
  [[ -z "$2" ]] && return 1

  git config --global gpg.format ssh
  git config --global user.signingkey "$2"
  git config --global commit.gpgsign true
}

## Set git line endings
function set_line_endings() {
  echo "Setting git line endings to: autocrlf"

  git config --global core.autocrlf input
}

## Set git editor
function set_editor() {
  git config --global core.editor "$1"
}

## Set global gitignore file
function set_global_gitignore() {
  local gitignore_path="$1"

  [[ -z "$gitignore_path" ]] && return

  echo "Creating global gitignore at: ${gitignore_path}"

  mkdir -p "$(dirname "${gitignore_path}")"

  printf "%s\n" "${DEFAULT_GITIGNORE_CONTENT}" > "${gitignore_path}"

  git config --global core.excludesfile "${gitignore_path}"
}

## Set merge conflict style
function set_conflict_style() {
  git config --global merge.conflictstyle "${1:-zdiff3}"
}

## Enable misspelled git command autocorrection
function set_autocorrect() {
  git config --global help.autocorrect "${1:-prompt}"
}

## Parse CLI args
function parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -u|--git-user)
        GIT_USERNAME="$2"
        shift 2
        ;;
      -e|--git-email)
        GIT_EMAIL="$2"
        shift 2
        ;;
      -b|--default-branch)
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
        GIT_SIGN_SSH_KEY="$2"
        shift 2 ;;
      -E|--editor)
        GIT_PREFERRED_EDITOR="$2"
        shift 2
        ;;
      -i|--default-gitignore)
        GENERATE_GLOBAL_GITIGNORE="$2"
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
  set_default_branch "${GIT_DEFAULT_BRANCH}"
  pull_rebase_enabled "${GIT_ENABLE_PULL_REBASE}"
  prune_on_fetch_enabled "${GIT_PRUNE_ON_FETCH}"
  auto_setup_remote_enabled "${GIT_AUTO_SETUP_REMOTE}"
  reuse_conflict_resolution_enabled "${GIT_REUSE_CONFLICT_RESOLUTION}"
  enable_color
  set_pager "${GIT_PAGER}"
  enable_signing "${GIT_ENABLE_SIGNING}" "${GIT_SIGN_SSH_KEY}"
  set_line_endings
  set_editor "${GIT_PREFERRED_EDITOR}"
  set_conflict_style
  set_autocorrect

  if [[ -n "${GENERATE_GLOBAL_GITIGNORE}" ]]; then
    set_global_gitignore "${GENERATE_GLOBAL_GITIGNORE}"
  fi

  if [[ -n "${GIT_USERNAME}" && -n "${GIT_EMAIL}" ]]; then
    set_git_user "${GIT_USERNAME}" "${GIT_EMAIL}"
  fi

  echo "Setup complete."
}

## Entrypoint
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  parse_args "$@"
  do_git_setup
fi
