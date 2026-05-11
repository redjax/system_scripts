#!/usr/bin/env bash
set -euo pipefail

THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${THIS_DIR}/_common.sh"

function usage() {
  cat <<'EOF'
Usage: run-section.sh SECTION [options]

Options:
  -h, --help                Show this help text
  -s, --subscription SUBS   Subscription ID/name to query (default: current)
  -o, --output FILE         Write output to FILE (strips color codes)

Sections:
  account, groups, resources, acr, aks, vms, webapps, plans, storage, sql, vaults, roles
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

SECTION="$1"
shift

SUBSCRIPTION=""
OUTPUT=""

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    -s|--subscription)
      [[ -z "${2:-}" ]] && { echo "[ERROR] --subscription requires a value" >&2; exit 1; }
      SUBSCRIPTION="$2"
      shift 2
      ;;
    -o|--output)
      [[ -z "${2:-}" ]] && { echo "[ERROR] --output requires a file path" >&2; exit 1; }
      OUTPUT="$2"
      shift 2
      ;;
    *)
      echo "[ERROR] Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

survey_require_az

if [[ -n "${OUTPUT}" ]]; then
  : >"$OUTPUT"
  LOG_PIPE="survey_strip_colors | tee -a \"$OUTPUT\""
else
  LOG_PIPE="cat"
fi

if [[ -z "${SURVEY_SECTIONS_AVAILABLE[$SECTION]:-}" ]]; then
  echo -e "${RED}[ERROR] Invalid section: $SECTION${NC}" | eval "$LOG_PIPE"
  usage | eval "$LOG_PIPE"
  exit 1
fi

if [[ -n "$SUBSCRIPTION" ]]; then
  if ! az account set --subscription "$SUBSCRIPTION" 2>/dev/null; then
    echo -e "${RED}Cannot access or set subscription: $SUBSCRIPTION${NC}" | eval "$LOG_PIPE"
    exit 1
  fi
fi

CURRENT_SUB="$(az account show --query '{id:id,name:name,tenantId:tenantId}' -o tsv 2>/dev/null || true)"
if [[ -z "$CURRENT_SUB" ]]; then
  echo -e "${RED}Failed to query current subscription details${NC}" | eval "$LOG_PIPE"
  exit 1
fi

IFS=$'\t' read -r SUB_ID SUB_NAME TENANT_ID <<<"$CURRENT_SUB"
survey_emit_subscription_header "$SUB_ID" "$SUB_NAME" "$TENANT_ID" | eval "$LOG_PIPE"
survey_run_section "$SECTION" | eval "$LOG_PIPE"
