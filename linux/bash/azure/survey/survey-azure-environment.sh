#!/usr/bin/env bash
set -euo pipefail

THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${THIS_DIR}/_common.sh"

## Show help message
function usage() {
  echo "Usage: $0 [options]"
  cat <<EOF

Options:
  -h, --help                       This help text
  -s, --subscription SUBS          Comma-separated subscription IDs/names (see: az account list) [default: current only]
  -c, --section SECTIONS           Comma-separated section names (default: all)
  -q, --quick                      Only show account info & resource groups
  -o, --output FILE                Write output to FILE (strips color codes)

Sections: account, groups, resources, acr, aks, vms, webapps, plans, storage, sql, vaults, roles, all

Examples:
  $0                                      # all info, current subscription only
  $0 -s subname1,subid2                   # run on those subscriptions only
  $0 -c vms,webapps                       # only show those sections
  $0 -q                                   # quick survey (account + groups)
  $0 -o survey.txt                        # save all output to survey.txt
EOF
  exit 0
}

## Parse CLI args
QUICK=0
OUTPUT=""
USER_SECTIONS=()
USER_SUBS=()
while [[ "$#" -gt 0 ]]; do
  case "$1" in
  -h | --help) usage ;;
  -q | --quick)
    QUICK=1
    shift
    ;;
  -o | --output)
    OUTPUT="$2"
    shift 2
    ;;
  -c | --section)
    IFS=',' read -ra USER_SECTIONS <<<"$2"
    shift 2
    ;;
  -s | --subscription)
    IFS=', ' read -ra USER_SUBS <<<"$2"
    shift 2
    ;;
  *)
    echo -e "${RED}Unknown argument: $1${NC}" >&2
    usage
    ;;
  esac
done

[[ ${#USER_SECTIONS[@]} -gt 0 && "${USER_SECTIONS[0]}" == "all" ]] && USER_SECTIONS=()

if [[ "$QUICK" == "1" ]]; then
  SECTIONS=("account" "groups")
elif [[ ${#USER_SECTIONS[@]} -gt 0 ]]; then
  SECTIONS=()
  for s in "${USER_SECTIONS[@]}"; do
    ns=$(echo "$s" | tr '[:upper:]' '[:lower:]')
    [[ "$ns" == "all" ]] && {
      SECTIONS=("${SURVEY_SECTIONS_ALL[@]}")
      break
    }
    [[ -n "${SURVEY_SECTIONS_AVAILABLE[$ns]:-}" ]] && SECTIONS+=("$ns") || echo -e "${YELLOW}[WARN] Skipping invalid section: $ns${NC}"
  done
  [[ ${#SECTIONS[@]} -eq 0 ]] && SECTIONS=("${SURVEY_SECTIONS_ALL[@]}")
else
  SECTIONS=("${SURVEY_SECTIONS_ALL[@]}")
fi

## Set up output file, if desired
if [[ -n "$OUTPUT" ]]; then
  : >"$OUTPUT" # truncate file now
  LOG_PIPE="survey_strip_colors | tee -a \"$OUTPUT\""
else
  LOG_PIPE="cat"
fi

survey_require_az

start_time=$(date)
CUR_SUB_ID=""

## Main output header
{
  echo -e "${GREEN}Azure Environment Survey Utility${NC}"
  echo "Script started at: $start_time"
} | eval "$LOG_PIPE"

# Determine which subscriptions to query
if [[ ${#USER_SUBS[@]} -eq 0 ]]; then
  CUR_INFO="$(az account show --query '{id:id,name:name,tenantId:tenantId}' -o tsv)"
  IFS=$'\t' read -r CUR_SUB_ID CUR_SUB_NAME CUR_TENANT_ID <<<"$CUR_INFO"
  USER_SUBS=("$CUR_SUB_ID")
fi

for sub in "${USER_SUBS[@]}"; do
  # Set subscription context (only if -s was given), skip if that isn't possible
  if [[ ${#USER_SUBS[@]} -gt 1 || ("${USER_SUBS[0]}" != "$CUR_SUB_ID") ]]; then
    if ! az account set --subscription "$sub" 2>/dev/null; then
      echo -e "${RED}Cannot access or set subscription: $sub${NC}" | eval "$LOG_PIPE"
      continue
    fi
  fi
  CUR_SUB=$(az account show --query '{id:id,name:name,tenantId:tenantId}' -o tsv 2>/dev/null || echo "")
  if [[ -z "$CUR_SUB" ]]; then
    echo -e "${RED}Failed to query details for subscription: $sub${NC}" | eval "$LOG_PIPE"
    continue
  fi
  IFS=$'\t' read -r SUB_ID SUB_NAME TENANT_ID <<<"$CUR_SUB"
  survey_emit_subscription_header "$SUB_ID" "$SUB_NAME" "$TENANT_ID" | eval "$LOG_PIPE"

  for sect in "${SECTIONS[@]}"; do
    survey_run_section "$sect" | eval "$LOG_PIPE"
  done
done

end_time=$(date)
echo -e "\n${GREEN}Survey complete.${NC} Started: $start_time | Ended: $end_time" | eval "$LOG_PIPE"

