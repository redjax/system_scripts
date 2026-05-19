#!/usr/bin/env bash

## Return local clone path from parsed URL parts
function infer_local_path() {
  local source="$1"
  local base="${2:-./repos}"

  local host repo

  source="${source#ssh://}"
  source="${source#https://}"
  source="${source#git@}"

  host="${source%%[:/]*}"
  host="${host#www.}"
  if [[ "$source" == *:* ]]; then
    repo="${source#*:}"
  else
    repo="${source#*/}"
  fi

  repo="${repo#/}"

  repo="${repo%.git}"

  printf "%s/%s/%s.git" "${base%/}" "${host}" "${repo}"
}

function ensure_dir() {
  local dir="$1"
  mkdir -p "$dir"
}

## Resolve a destination spec into a URL.
## Accepts either name=url or plain URL.
function resolve_target_url() {
  local spec="$1"

  if [[ "$spec" == *"="* ]]; then
    printf '%s\n' "${spec#*=}"
  else
    printf '%s\n' "$spec"
  fi
}

## Resolve a destination spec into a git remote name.
## Plain URLs get auto-generated names based on index.
function resolve_target_name() {
  local spec="$1"
  local index="$2"

  if [[ "$spec" == *"="* ]]; then
    printf '%s\n' "${spec%%=*}"
  else
    printf 'target%d\n' "$index"
  fi
}

function handle_error() {
  local exit_code="$1"
  local line="$2"
  local cmd="$3"

  # ignore harmless failures from conditionals
  case "$cmd" in
  \[\[* | test* | grep*)
    return
    ;;
  esac

  error "Command failed (exit=$exit_code) at line $line"
  error "Failed command: $cmd"

  exit "$exit_code"
}
