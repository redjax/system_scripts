#!/usr/bin/env bash
set -euo pipefail

function survey_section_webapps() {
  survey_section_header "Web Apps"
  survey_run_az "web apps" az webapp list --output table
}

THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${THIS_DIR}/_entrypoint.sh"
survey_section_exec_if_direct "webapps" "$@"
