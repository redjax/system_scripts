#!/usr/bin/env bash
set -euo pipefail

function survey_section_storage() {
  survey_section_header "Storage Accounts"
  survey_run_az "storage accounts" az storage account list --output table
}

THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${THIS_DIR}/_entrypoint.sh"
survey_section_exec_if_direct "storage" "$@"
