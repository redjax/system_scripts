#!/usr/bin/env bash

GIT_SSH_COMMAND=""
GIT_HTTP_EXTRA_HEADER=""
AUTH_TMP_DIR=""

function detect_auth() {
  local url="$1"

  case "$url" in
  git@*:* | ssh://* | git://*) echo "ssh" ;;
  https://*) echo "https" ;;
  *) echo "ssh" ;;
  esac
}

function auth_cleanup() {
  if [[ -n "${AUTH_TMP_DIR:-}" && -d "${AUTH_TMP_DIR}" ]]; then
    rm -rf "${AUTH_TMP_DIR}"
  fi
}

function setup_auth() {
  local url="${1:-}"
  local mode="${AUTH_MODE:-}"

  if [[ -z "$mode" ]]; then
    mode="$(detect_auth "$url")"
  fi

  GIT_SSH_COMMAND=""
  GIT_HTTP_EXTRA_HEADER=""

  if [[ -n "${SSH_KEY_FILE:-}" && -n "${SSH_KEY_ENV:-}" ]]; then
    error "set either SSH_KEY_FILE or SSH_KEY_ENV, not both"
    exit 2
  fi

  if [[ -n "${HTTPS_TOKEN:-}" && -n "${HTTPS_TOKEN_ENV:-}" ]]; then
    error "set either HTTPS_TOKEN or HTTPS_TOKEN_ENV, not both"
    exit 2
  fi

  case "$mode" in
  ssh)
    if [[ -n "${SSH_KEY_FILE:-}" ]]; then
      export GIT_SSH_COMMAND="ssh -i ${SSH_KEY_FILE} -o IdentitiesOnly=yes"
    elif [[ -n "${SSH_KEY_ENV:-}" ]]; then
      local key="${!SSH_KEY_ENV:-}"
      [[ -n "$key" ]] || {
        error "SSH key env var is empty: ${SSH_KEY_ENV}"
        exit 2
      }

      AUTH_TMP_DIR="$(mktemp -d)"
      local f="${AUTH_TMP_DIR}/key"
      printf '%s\n' "$key" >"$f"
      chmod 600 "$f"
      export GIT_SSH_COMMAND="ssh -i ${f} -o IdentitiesOnly=yes"
    else
      export GIT_SSH_COMMAND="ssh -o IdentitiesOnly=yes"
    fi
    ;;
  https)
    if [[ -n "${HTTPS_TOKEN_ENV:-}" ]]; then
      local token="${!HTTPS_TOKEN_ENV:-}"
      [[ -n "$token" ]] || {
        error "HTTPS token env var is empty: ${HTTPS_TOKEN_ENV}"
        exit 2
      }
      export GIT_HTTP_EXTRA_HEADER="Authorization: Bearer ${token}"
    elif [[ -n "${HTTPS_TOKEN:-}" ]]; then
      export GIT_HTTP_EXTRA_HEADER="Authorization: Bearer ${HTTPS_TOKEN}"
    fi
    ;;
  *)
    error "Unsupported auth mode: ${mode}"
    exit 2
    ;;
  esac

  debug "auth mode: $mode"
}
