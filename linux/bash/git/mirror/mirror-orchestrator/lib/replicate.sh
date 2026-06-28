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

  info "replicating $src -> $dst"

  if [[ -n "${GIT_HTTP_EXTRA_HEADER:-}" ]]; then
    ## Add auth & other headers if present
    run_cmd git -c "http.extraHeader=${GIT_HTTP_EXTRA_HEADER}" clone --mirror "$src" "$path"
  else
    ## Standard git mirror clone
    run_cmd git clone --mirror "$src" "$path"
  fi

  ## Push local mirror to remote
  run_cmd git -C "$path" remote add target "$dst"

  if [[ -n "${GIT_HTTP_EXTRA_HEADER:-}" ]]; then
    run_cmd git -C "$path" -c "http.extraHeader=${GIT_HTTP_EXTRA_HEADER}" push --mirror target
  else
    run_cmd git -C "$path" push --mirror target
  fi
}
