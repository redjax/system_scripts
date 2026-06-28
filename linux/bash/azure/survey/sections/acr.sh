#!/usr/bin/env bash
set -euo pipefail

function survey_section_acr() {
  survey_section_header "Container Registries"
  survey_run_az "container registries" az acr list --output table
}

THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${THIS_DIR}/_entrypoint.sh"
survey_section_exec_if_direct "acr" "$@"
