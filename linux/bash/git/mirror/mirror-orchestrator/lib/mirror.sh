#!/usr/bin/env bash

##############################################################################
# Create a mirror locally, and optionally to 1 or more remote.               #
# Git mirror docs:                                                           #
#   https://git-scm.com/docs/git-clone#Documentation/git-clone.txt---mirror  #
##############################################################################

function mirror_run() {
  local url="$1"
  local root="${LOCAL_ROOT:-./repos}"

  local path
  path="$(infer_local_path "$url" "$root")"

  info "Mirror path: $path"
  info "Source: $url"

  clone_or_update "$url" "$path"

  info "Mirror complete"
}
