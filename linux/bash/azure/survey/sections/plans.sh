#!/usr/bin/env bash
set -euo pipefail

function survey_section_plans() {
  survey_section_header "App Service Plans"
  survey_run_az "app service plans" az appservice plan list --output table
}

THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${THIS_DIR}/_entrypoint.sh"
survey_section_exec_if_direct "plans" "$@"
