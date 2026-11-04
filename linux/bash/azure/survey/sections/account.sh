#!/usr/bin/env bash
set -euo pipefail

function survey_section_account() {
  survey_section_header "Account & Subscription Info"
  survey_run_az "account info" az account show --output table

  if ! az ad signed-in-user show --output table 2>/dev/null; then
    echo -e "${YELLOW}[WARN] Could not get signed-in user info.${NC}"
  fi
  echo

  local user_obj_id=""
  user_obj_id="$(survey_get_signed_in_user_id || true)"
  if [[ -n "$user_obj_id" ]]; then
    echo "[Role assignments for you in this sub:]"
    if ! az role assignment list --assignee "$user_obj_id" --output table 2>/dev/null; then
      echo -e "${YELLOW}[WARN] Could not get your role assignments.${NC}"
    fi
    echo
  fi
}

THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${THIS_DIR}/_entrypoint.sh"
survey_section_exec_if_direct "account" "$@"
