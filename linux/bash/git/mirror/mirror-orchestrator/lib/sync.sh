#!/usr/bin/env bash

function sync_run() {
  local url="$1"
  local root="${LOCAL_ROOT:-./repos}"
  shift || true

  local path
  path="$(infer_local_path "$url" "$root")"

  clone_or_update "$url" "$path"

  local i=0
  for dest in "$@"; do
    i=$((i + 1))

    local name target
    name="$(resolve_target_name "$dest" "$i")"
    target="$(resolve_target_url "$dest")"

    info "sync -> $name"

    if git -C "$path" remote get-url "$name" >/dev/null 2>&1; then
      run_cmd git -C "$path" remote set-url "$name" "$target"
    else
      run_cmd git -C "$path" remote add "$name" "$target"
    fi

    run_cmd git -C "$path" push --mirror "$name"
  done
}
