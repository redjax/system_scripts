#!/usr/bin/env bash
set -euo pipefail

###############################################################
# Mirror a remote git repository to local storage.            #
#                                                             #
# For public repos, you do not need to pass any auth.         #
#                                                             #
# For private repos, you need to pass a token for HTTPS auth  #
# and an SSH key for SSH auth. If you've configured a key for #
# the remote in ~/.ssh/config, it will be used automatically. #
###############################################################

function usage() {
  cat << EOF
Usage:
  $0 [OPTIONS]

Options:
  -h, --help         Print this help menu
  --url <repo_url>   URL of remote repository. Can be HTTPS or SSH
  --dest <path>      Path on local filesystem to clone to
  --token <token>    HTTPS authentication token
  --ssh-key <path>   SSH private key path
EOF
}

URL=""
DEST=""
TOKEN=""
SSH_KEY=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    --url)
      URL="$2"
      shift 2
      ;;
    --dest)
      DEST="$2"
      shift 2
      ;;
    --token)
      TOKEN="$2"
      shift 2
      ;;
    --ssh-key)
      SSH_KEY="$2"
      shift 2
      ;;
    *)
      echo "[ERROR] Invalid argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$URL" ]] || [[ -z "$DEST" ]]; then
  echo "[ERROR] Missing --url or --dest arguments" >&2
  usage
  exit 1
fi

## Attempt to load token from environment if not defined
if [[ -z "$TOKEN" ]]; then
  TOKEN="${GIT_TOKEN:-}"
fi

mkdir -p "$(dirname "$DEST")"

## SSH override
if [[ -n "$SSH_KEY" ]]; then
  export GIT_SSH_COMMAND="ssh -i $SSH_KEY -o IdentitiesOnly=yes"
fi

AUTH_URL="$URL"

## HTTPS auth injection
if [[ "$URL" == https://* ]]; then
  if [[ -n "$TOKEN" ]]; then
    AUTH_URL="${URL/https:\/\//https:\/\/x-access-token:${TOKEN}@}"
  fi
fi

## Clone or update mirror
if [[ ! -d "$DEST" ]]; then
  echo "[+] Cloning mirror: $URL"
  git clone --mirror "$AUTH_URL" "$DEST"
else
  echo "[+] Updating mirror: $DEST"

  CURRENT_URL="$(git -C "$DEST" remote get-url origin)"

  if [[ "$CURRENT_URL" != "$AUTH_URL" ]]; then
    echo "[+] Updating remote URL"
    git -C "$DEST" remote set-url origin "$AUTH_URL"
  fi

  ## Enforce mirror mode so fetch/push operations fully sync all refs and prune deleted branches
  git -C "$DEST" config remote.origin.mirror true

  ## Full sync
  git -C "$DEST" fetch --all --prune
  git -C "$DEST" fetch --prune --tags origin
fi
