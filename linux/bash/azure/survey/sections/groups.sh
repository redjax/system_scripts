#!/usr/bin/env bash
set -euo pipefail

function survey_section_groups() {
  survey_section_header "Resource Groups"
  survey_run_az "resource groups" az group list --output table
}

THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${THIS_DIR}/_entrypoint.sh"
survey_section_exec_if_direct "groups" "$@"
