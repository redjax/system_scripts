#!/usr/bin/env bash
set -euo pipefail

if ! command -v git >/dev/null 2>&1; then
  echo "[ERROR] git is not installed. Install git before running this script." >&2
  exit 1
fi

GITLOG_ADVANCED_FORMAT="%C(yellow)%h%C(reset) %C(green)%ar%C(reset) %C(blue)%an%C(reset)%C(auto)%d%C(reset) %s"

GIT_USERNAME=""
GIT_EMAIL=""
GIT_DEFAULT_BRANCH="main"
GIT_ENABLE_PULL_REBASE="false"
GIT_PRUNE_ON_FETCH="false"
GIT_AUTO_SETUP_REMOTE="false"
GIT_REUSE_CONFLICT_RESOLUTION="false"

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
  -a, --auto-setup-remote  Create remote branches on push (default: false)
  -r, --reuse-conflict     Reuse conflict resolution (default: false, usually true)

Example:
  $(basename "$0") -u "John Doe" -e "john@example.com"
EOF
}

function set_git_aliases() {
  local advanced_format="$1"

  echo "Setting git aliases"
  
  echo
  echo "Setting alias: lg (git log)"
  git config --global alias.lg "log --graph --oneline --decorate"

  echo
  echo "Setting alias: lga (git log advanced)"
  git config --global alias.lga \
    "log --graph --pretty=format:'${advanced_format}' --abbrev-commit"

  echo
  echo "Setting alias: st (git status)"
  git config --global alias.st status

  echo
  echo "Setting alias: co (git checkout)"
  git config --global alias.co checkout

  echo
  echo "Setting alias: sw (git switch)"
  git config --global alias.sw switch

  echo
  echo "Setting alias: br (git branch)"
  git config --global alias.br branch

  echo
  echo "Setting alias: ci (git commit)"
  git config --global alias.ci commit

  echo
  echo "Setting alias: last (git last commit)"
  git config --global alias.last "log -1 HEAD"

  echo
  echo "Setting alias: unstage (git restore --staged)"
  git config --global alias.unstage "restore --staged"

  echo
  echo "Setting alias: graph (git graph)"
  git config --global alias.graph "log --graph --decorate --oneline --all"
}

function set_git_user() {
  local username="$1"
  local email_addr="$2"

  echo "Setting git user to: ${username} <${email_addr}>"

  git config --global user.name "${username}"
  git config --global user.email "${email_addr}"
}

function set_default_branch() {
  local branch="$1"

  echo "Setting default branch to: ${branch}"

  git config --global init.defaultBranch "${branch}"
}

function pull_rebase_enabled() {
  local enabled="false"

  echo "Pull rebase enabled: ${enabled}"

  git config --global pull.rebase false
}

function prune_on_fetch_enabled() {
  local enabled="false"

  echo "Prune on fetch enabled: ${enabled}"

  git config --global fetch.prune true
}

function auto_setup_remote_() {
  local enabled="false"

  echo "Create remote branch on push enabled: ${enabled}"

  git config --global push.autoSetupRemote true
}

function reuse_conflict_resolution_enabled() {
  local enabled="false"

  echo "Reuse conflict resolution enabled: ${enabled}"

  git config --global rerere.enabled true
}

function enable_color() {
  echo "Set git color output to auto"
  
  git config --global color.ui auto
}

function set_pager() {
  local pager="${1:-less -FRX}"
  echo "Setting git pager to: ${pager}"

  git config --global core.pager "${pager}"
}

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
    -h|--help)
      usage
      exit 0
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
    *)
      echo "[ERROR] Invalid arg: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "${GIT_DEFAULT_BRANCH}" ]]; then
  GIT_DEFAULT_BRANCH="main"
fi

set_git_aliases "${GITLOG_ADVANCED_FORMAT}"
echo

set_default_branch "${GIT_DEFAULT_BRANCH}"
echo

pull_rebase_enabled "${GIT_ENABLE_PULL_REBASE}"
echo

prune_on_fetch_enabled "${GIT_PRUNE_ON_FETCH}"
echo

auto_setup_remote_ "${GIT_AUTO_SETUP_REMOTE}"
echo

reuse_conflict_resolution_enabled "${GIT_REUSE_CONFLICT_RESOLUTION}"
echo

enable_color
echo

set_pager "${GIT_PAGER}"
echo

if [[ -n "${GIT_USERNAME}" && -n "${GIT_EMAIL}" ]]; then
  set_git_user "${GIT_USERNAME}" "${GIT_EMAIL}"
else
  echo "[INFO] Git username/email not provided. Skipping git user config."
fi

echo "Setup complete."
