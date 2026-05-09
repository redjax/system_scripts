#!/usr/bin/env bash
set -euo pipefail

if ! command -v git >/dev/null 2>&1; then
  echo "[ERROR] git is not installed. Install git before running this script." >&2
  exit 1
fi

GITLOG_ADVANCED_FORMAT="%C(yellow)%h%C(reset) %C(green)%ar%C(reset) %C(blue)%an%C(reset)%C(auto)%d%C(reset) %s"

GIT_USERNAME=""
GIT_EMAIL=""

function usage() {
  cat <<EOF
USAGE: $(basename "$0") [OPTIONS]

Options:
  -h, --help         Print this help menu
  -u, --git-user     The username to set for git config user.name
  -e, --git-email    The email address to set for git config user.email

Example:
  $(basename "$0") -u "John Doe" -e "john@example.com"
EOF
}

function set_git_aliases() {
  local advanced_format="$1"

  echo "Setting git aliases"
  
  echo
  echo "Alias: lg"
  git config --global alias.lg "log --graph --oneline --decorate"

  echo
  echo "Alias: lga"
  git config --global alias.lga \
    "log --graph --pretty=format:'${advanced_format}' --abbrev-commit"
}

function set_git_user() {
  local username="$1"
  local email_addr="$2"

  echo "Setting git user to: ${username} <${email_addr}>"

  git config --global user.name "${username}"
  git config --global user.email "${email_addr}"
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

    *)
      echo "[ERROR] Invalid arg: $1" >&2
      usage
      exit 1
      ;;
  esac
done

set_git_aliases "${GITLOG_ADVANCED_FORMAT}"
echo

if [[ -n "${GIT_USERNAME}" && -n "${GIT_EMAIL}" ]]; then
  set_git_user "${GIT_USERNAME}" "${GIT_EMAIL}"
else
  echo "[INFO] Git username/email not provided. Skipping git user config."
fi

echo "Setup complete."
