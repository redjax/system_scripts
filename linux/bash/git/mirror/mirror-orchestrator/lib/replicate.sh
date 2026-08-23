#!/usr/bin/env bash

#############################################################
# Replicate creates a mirror from one remote to another.    #
#                                                           #
# It removes the local clone after mirroring to the remote. #
#############################################################

function replicate_run() {
  local src="$1"
  local dst="$2"

  [[ -n "$dst" ]] || {
    error "replicate destination is required"
    exit 2
  }

  local tmp
  tmp="$(mktemp -d)"
  local path="$tmp/repo.git"

  # Always clean temp mirror, even if clone/push fails.
  trap "rm -rf \"$tmp\"" RETURN

  info "replicating source ${src} to destination ${dst}"

  if [[ -n "${GIT_HTTP_EXTRA_HEADER:-}" ]]; then
    ## Add auth & other headers if present
    if ! run_git_cmd "$src" git -c "http.extraHeader=${GIT_HTTP_EXTRA_HEADER}" clone --mirror "$src" "$path"; then
      return 1
    fi
  else
    ## Standard git mirror clone
    if ! run_git_cmd "$src" git clone --mirror "$src" "$path"; then
      return 1
    fi
  fi

  ## Push local mirror to remote
  run_cmd git -C "$path" remote add target "$dst"

  if [[ -n "${GIT_HTTP_EXTRA_HEADER:-}" ]]; then
    if ! run_git_cmd "$dst" git -C "$path" -c "http.extraHeader=${GIT_HTTP_EXTRA_HEADER}" push --mirror target; then
      return 1
    fi
  else
    if ! run_git_cmd "$dst" git -C "$path" push --mirror target; then
      return 1
    fi
  fi
}
