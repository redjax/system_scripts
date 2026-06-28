#!/usr/bin/env bash
set -euo pipefail

function survey_section_roles() {
  survey_section_header "Role Assignments for Current User"
  local user_obj_id=""
  user_obj_id="$(survey_get_signed_in_user_id || true)"

  if [[ -n "$user_obj_id" ]]; then
    survey_run_az "role assignments for current user" az role assignment list --assignee "$user_obj_id" --output table
  else
    echo -e "${YELLOW}[WARN] Could not fetch signed-in user info (possibly missing permissions)${NC}"
    echo
  fi
}

THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${THIS_DIR}/_entrypoint.sh"
survey_section_exec_if_direct "roles" "$@"
