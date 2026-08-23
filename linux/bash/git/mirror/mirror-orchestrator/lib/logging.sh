#!/usr/bin/env bash

LOG_DEBUG="0"
LOG_VERBOSE="0"
LOG_DRY_RUN="0"

function init_logging() {
  LOG_DEBUG="${1:-0}"
  LOG_VERBOSE="${2:-0}"
  LOG_DRY_RUN="${3:-0}"
}

function ts() { date +"%Y-%m-%d %H:%M:%S"; }

function info() { printf '[%s] INFO: %s\n' "$(ts)" "$*"; }
function warn() { printf '[%s] WARN: %s\n' "$(ts)" "$*" >&2; }
function error() { printf '[%s] ERROR: %s\n' "$(ts)" "$*" >&2; }

function debug() {
  if [[ "${LOG_DEBUG:-0}" == "1" ]]; then
    printf '[%s] DEBUG: %s\n' "$(date +"%Y-%m-%d %H:%M:%S")" "$*" >&2
  fi

  return 0
}

function verbose() {
  if [[ "${LOG_VERBOSE:-0}" == "1" ]]; then
    printf '[%s] VERBOSE: %s\n' "$(date +"%Y-%m-%d %H:%M:%S")" "$*" >&2
  fi

  return 0
}

## Run a command wrapped in logging
function run_cmd() {
  if [[ "${LOG_DRY_RUN}" == "1" ]]; then
    printf '[%s] DRY-RUN:' "$(ts)" >&2
    printf ' %q' "$@" >&2
    printf '\n' >&2

    return 0
  fi

  verbose "$@"

  ## Show git commands when DEBUG is enabled
  if [[ "${LOG_DEBUG}" == "1" ]]; then
    printf '[%s] DEBUG CMD:' "$(ts)" >&2
    printf ' %q' "$@" >&2
    printf '\n' >&2
  fi

  "$@"
}
