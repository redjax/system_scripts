#!/usr/bin/env bash
set -euo pipefail

function survey_section_aks() {
  survey_section_header "Kubernetes Clusters (AKS)"
  survey_run_az "Kubernetes clusters" az aks list --output table
}

THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${THIS_DIR}/_entrypoint.sh"
survey_section_exec_if_direct "aks" "$@"
