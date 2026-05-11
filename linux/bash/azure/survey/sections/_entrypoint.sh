#!/usr/bin/env bash
set -euo pipefail

function survey_section_exec_if_direct() {
  local section_name="$1"
  shift

  # If this section file is executed directly, delegate to run-section.sh.
  if [[ "${BASH_SOURCE[1]}" == "${0}" ]]; then
    local this_dir=""
    this_dir="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
    exec "${this_dir}/../run-section.sh" "$section_name" "$@"
  fi
}
