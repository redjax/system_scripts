#!/usr/bin/env bash

function clone_or_update() {
  local url="$1"
  local path="$2"

  if [[ -d "$path" ]]; then
    info "Updating mirror"

    if [[ -n "${GIT_HTTP_EXTRA_HEADER:-}" ]]; then
      run_cmd git -C "$path" -c "http.extraHeader=${GIT_HTTP_EXTRA_HEADER}" remote update --prune
    else
      run_cmd git -C "$path" remote update --prune
    fi
  else
    info "Cloning mirror"
    ensure_dir "$(dirname "$path")"

    if [[ -n "${GIT_HTTP_EXTRA_HEADER:-}" ]]; then
      run_cmd git -c "http.extraHeader=${GIT_HTTP_EXTRA_HEADER}" clone --mirror "$url" "$path"
    else
      run_cmd git clone --mirror "$url" "$path"
    fi
  fi
}
