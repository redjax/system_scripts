#!/usr/bin/env bash

function classify_git_error() {
  local err="$1"

  if echo "$err" | grep -qiE 'repository not found|repo not found|could not read from remote repository'; then
    echo "repo_not_found"
  elif echo "$err" | grep -qiE 'permission denied|authentication failed|access denied|unauthorized|remote repository not found'; then
    echo "auth"
  elif echo "$err" | grep -qiE 'could not resolve host|network is unreachable|connection timed out|connection refused|temporary failure'; then
    echo "network"
  elif echo "$err" | grep -qiE 'ssh_exchange_identification|no route to host|host key verification failed'; then
    echo "ssh"
  else
    echo "unknown"
  fi
}

function git_error_hint() {
  local kind="$1"
  local target="$2"

  case "$kind" in
  repo_not_found)
    error "Destination repository was not found or is not accessible: $target"
    error "Check the remote URL, repository path, and write permissions."
    ;;
  auth)
    error "Authentication failed while accessing: $target"
    error "Check SSH key, token, account permissions, or remote ACLs."
    ;;
  network)
    error "Network error while reaching: $target"
    error "Check connectivity and host availability."
    ;;
  ssh)
    error "SSH error while reaching: $target"
    error "Check SSH connectivity, host key verification, and agent/key setup."
    ;;
  *)
    error "Git operation failed for: $target"
    error "See raw error output below."
    ;;
  esac
}

function run_git_cmd() {
  local target="$1"
  shift

  local err_file
  err_file="$(mktemp)"
  if ! "$@" 2>"$err_file"; then
    local rc=$?
    local err
    err="$(cat "$err_file")"
    local kind
    kind="$(classify_git_error "$err")"

    git_error_hint "$kind" "$target"
    if [[ -n "$err" ]]; then
      printf '%s\n' "$err" >&2
    fi

    rm -f "$err_file"
    return "$rc"
  fi

  rm -f "$err_file"
}

function clone_or_update() {
  local url="$1"
  local path="$2"

  if [[ -d "$path" ]]; then
    info "Updating mirror"

    if [[ -n "${GIT_HTTP_EXTRA_HEADER:-}" ]]; then
      run_git_cmd "$url" git -C "$path" -c "http.extraHeader=${GIT_HTTP_EXTRA_HEADER}" remote update --prune
    else
      run_git_cmd "$url" git -C "$path" remote update --prune
    fi
  else
    info "Cloning mirror"
    ensure_dir "$(dirname "$path")"

    if [[ -n "${GIT_HTTP_EXTRA_HEADER:-}" ]]; then
      run_git_cmd "$url" git -c "http.extraHeader=${GIT_HTTP_EXTRA_HEADER}" clone --mirror "$url" "$path"
    else
      run_git_cmd "$url" git clone --mirror "$url" "$path"
    fi
  fi
}
