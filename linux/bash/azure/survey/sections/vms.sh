#!/usr/bin/env bash
set -euo pipefail

function survey_section_vms() {
  survey_section_header "Virtual Machines"
  survey_run_az "virtual machines" az vm list -d --output table
}

THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${THIS_DIR}/_entrypoint.sh"
survey_section_exec_if_direct "vms" "$@"
