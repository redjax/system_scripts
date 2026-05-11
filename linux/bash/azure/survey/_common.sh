#!/usr/bin/env bash
set -euo pipefail

SURVEY_COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SURVEY_SECTIONS_DIR="${SURVEY_COMMON_DIR}/sections"

## Colors for readability
GREEN="\033[1;32m"
CYAN="\033[1;36m"
RED="\033[1;31m"
YELLOW="\033[1;33m"
NC="\033[0m"

## Supported survey sections
SURVEY_SECTIONS_ALL=(account groups resources acr aks vms webapps plans storage sql vaults roles)
declare -A SURVEY_SECTIONS_AVAILABLE
for section_name in "${SURVEY_SECTIONS_ALL[@]}"; do
  SURVEY_SECTIONS_AVAILABLE["$section_name"]=1
done

function survey_divider() {
  printf "${CYAN}%s${NC}\n" "------------------------------------------------------------"
}

function survey_section_header() {
  survey_divider
  printf "${GREEN}[ %s ]${NC}\n" "$1"
  survey_divider
}

function survey_strip_colors() {
  sed -r "s/\x1B\[[0-9;]*[JKmsu]//g"
}

function survey_require_az() {
  if ! command -v az >/dev/null 2>&1; then
    printf "${RED}[ERROR] The Azure CLI (az) is not installed${NC}\n" >&2
    exit 1
  fi
}

function survey_run_az() {
  local desc="$1"
  shift
  local output

  if ! output="$("$@" 2>&1)"; then
    if echo "$output" | grep -qi "authentication"; then
      printf "${RED}[AUTH ERROR] %s -- Check your Azure login status and permissions.${NC}\n" "$desc"
    elif echo "$output" | grep -qi "authorization"; then
      printf "${RED}[PERMISSION ERROR] %s -- Access denied for this operation.${NC}\n" "$desc"
    else
      printf "${RED}[ERROR] Failed to run: %s${NC}\n%s\n" "$desc" "$output"
    fi
    echo
    return 0
  fi

  if [[ -z "${output// /}" || "$output" == "[]" ]]; then
    printf "${YELLOW}[NONE] No %s found in this subscription.${NC}\n\n" "$desc"
  else
    echo "$output"
    echo
  fi
}

function survey_get_signed_in_user_id() {
  local user_id
  user_id="$(az ad signed-in-user show --query id -o tsv 2>/dev/null || true)"
  if [[ -n "$user_id" ]]; then
    echo "$user_id"
    return 0
  fi

  user_id="$(az ad signed-in-user show --query objectId -o tsv 2>/dev/null || true)"
  if [[ -n "$user_id" ]]; then
    echo "$user_id"
    return 0
  fi

  return 1
}

function survey_emit_subscription_header() {
  local sub_id="$1"
  local sub_name="$2"
  local tenant_id="$3"
  echo -e "${YELLOW}===[ SUBSCRIPTION: $sub_name ($sub_id) | TENANT: $tenant_id ]===${NC}"
}

function survey_load_section_impl() {
  local section_name="$1"
  local section_file="${SURVEY_SECTIONS_DIR}/${section_name}.sh"

  if [[ ! -f "$section_file" ]]; then
    echo -e "${RED}[ERROR] Missing section implementation: $section_file${NC}" >&2
    return 1
  fi

  # shellcheck source=/dev/null
  source "$section_file"
  return 0
}

for section_name in "${SURVEY_SECTIONS_ALL[@]}"; do
  survey_load_section_impl "$section_name"
done

function survey_run_section() {
  local section_name="$1"
  local section_function="survey_section_${section_name}"

  if [[ -z "${SURVEY_SECTIONS_AVAILABLE[$section_name]:-}" ]]; then
    echo -e "${YELLOW}[WARN] Skipping invalid section: $section_name${NC}"
    return 0
  fi

  if ! declare -F "$section_function" >/dev/null; then
    echo -e "${RED}[ERROR] Missing function for section: $section_name${NC}"
    return 1
  fi

  "$section_function"
}
