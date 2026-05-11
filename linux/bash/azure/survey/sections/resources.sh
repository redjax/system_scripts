#!/usr/bin/env bash
set -euo pipefail

function survey_section_resources() {
  survey_section_header "All Resources"
  survey_run_az "resources" az resource list --output table
}

THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${THIS_DIR}/_entrypoint.sh"
survey_section_exec_if_direct "resources" "$@"
