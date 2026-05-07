#!/usr/bin/env bash
set -euo pipefail

## Colors for readability
GREEN="\033[1;32m"
CYAN="\033[1;36m"
RED="\033[1;31m"
YELLOW="\033[1;33m"
NC="\033[0m"

## Print section divider
function divider() {
  printf "${CYAN}%s${NC}\n" "------------------------------------------------------------"
}

## Print a section heading
function section() {
  divider
  printf "${GREEN}[ %s ]${NC}\n" "$1"
  divider
}

## Run and display an az CLI command (with error/none detection)
function run_az() {
  local desc="$1"
  shift
  local output
  if ! output="$("$@" 2>&1)"; then
    if echo "$output" | grep -qi "authentication"; then
      printf "${RED}[AUTH ERROR] %s -- Check your Azure login status and permissions.${NC}\n" "$desc"
    elif echo "$output" | grep -iq "authorization"; then
      printf "${RED}[PERMISSION ERROR] %s -- Access denied for this operation.${NC}\n" "$desc"
    else
      printf "${RED}[ERROR] Failed to run: %s${NC}\n%s\n" "$desc" "$output"
    fi
    echo
    return 1
  fi
  if [[ -z "${output// /}" || "$output" == "[]" ]]; then
    printf "${YELLOW}[NONE] No %s found in this subscription.${NC}\n\n" "$desc"
  else
    echo "$output"
    echo
  fi
  return 0
}

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

## Strip color codes for output-to-file
function strip_colors() {
  sed -r "s/\x1B\[[0-9;]*[JKmsu]//g"
}

## SECTION NAMES
SECTIONS_ALL=(account groups resources acr aks vms webapps plans storage sql vaults roles)
declare -A SECTIONS_AVAILABLE
for s in "${SECTIONS_ALL[@]}"; do SECTIONS_AVAILABLE["$s"]=1; done

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
      SECTIONS=("${SECTIONS_ALL[@]}")
      break
    }
    [[ -n "${SECTIONS_AVAILABLE[$ns]:-}" ]] && SECTIONS+=("$ns") || echo -e "${YELLOW}[WARN] Skipping invalid section: $ns${NC}"
  done
  [[ ${#SECTIONS[@]} -eq 0 ]] && SECTIONS=("${SECTIONS_ALL[@]}")
else
  SECTIONS=("${SECTIONS_ALL[@]}")
fi

## Set up output file, if desired
if [[ -n "$OUTPUT" ]]; then
  : >"$OUTPUT" # truncate file now
  LOG_PIPE="strip_colors | tee -a \"$OUTPUT\""
else
  LOG_PIPE="cat"
fi

## Check for Azure CLI program
if ! command -v az >/dev/null 2>&1; then
  printf "${RED}[ERROR] The Azure CLI (az) is not installed${NC}\n" >&2
  exit 1
fi

start_time=$(date)

## Main output header
{
  echo -e "${GREEN}Azure Environment Survey Utility${NC}"
  echo "Script started at: $start_time"
} | eval "$LOG_PIPE"

# Determine which subscriptions to query
if [[ ${#USER_SUBS[@]} -eq 0 ]]; then
  CUR_INFO=$(az account show --query '{id:id,name:name,tenantId:tenantId}' -o tsv)
  CUR_SUB_ID=$(echo "$CUR_INFO" | awk '{print $1}')
  CUR_SUB_NAME=$(echo "$CUR_INFO" | awk '{print $2}')
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
  CUR_SUB=$(az account show --query '[id,name,tenantId]' -o tsv 2>/dev/null || echo "")
  if [[ -z "$CUR_SUB" ]]; then
    echo -e "${RED}Failed to query details for subscription: $sub${NC}" | eval "$LOG_PIPE"
    continue
  fi
  SUB_ID=$(echo "$CUR_SUB" | awk '{print $1}')
  SUB_NAME=$(echo "$CUR_SUB" | awk '{print $2}')
  TENANT_ID=$(echo "$CUR_SUB" | awk '{print $3}')
  echo -e "${YELLOW}===[ SUBSCRIPTION: $SUB_NAME ($SUB_ID) | TENANT: $TENANT_ID ]===${NC}" | eval "$LOG_PIPE"

  for sect in "${SECTIONS[@]}"; do
    case "$sect" in
    account)
      section "Account & Subscription Info" | eval "$LOG_PIPE"
      run_az "account info" az account show --output table | eval "$LOG_PIPE"
      az ad signed-in-user show --output table 2>/dev/null | eval "$LOG_PIPE" ||
        echo -e "${YELLOW}[WARN] Could not get signed-in user info.${NC}" | eval "$LOG_PIPE"
      USER_OBJ_ID=$(az ad signed-in-user show --query objectId -o tsv 2>/dev/null || echo "")
      [[ -n "$USER_OBJ_ID" ]] && {
        echo "[Role assignments for you in this sub:]" | eval "$LOG_PIPE"
        az role assignment list --assignee "$USER_OBJ_ID" --output table 2>/dev/null | eval "$LOG_PIPE" ||
          echo -e "${YELLOW}[WARN] Could not get your role assignments.${NC}" | eval "$LOG_PIPE"
      }
      ;;
    groups)
      section "Resource Groups" | eval "$LOG_PIPE"
      run_az "resource groups" az group list --output table | eval "$LOG_PIPE"
      ;;
    resources)
      section "All Resources" | eval "$LOG_PIPE"
      run_az "resources" az resource list --output table | eval "$LOG_PIPE"
      ;;
    acr)
      section "Container Registries" | eval "$LOG_PIPE"
      run_az "container registries" az acr list --output table | eval "$LOG_PIPE"
      ;;
    aks)
      section "Kubernetes Clusters (AKS)" | eval "$LOG_PIPE"
      run_az "Kubernetes clusters" az aks list --output table | eval "$LOG_PIPE"
      ;;
    vms)
      section "Virtual Machines" | eval "$LOG_PIPE"
      run_az "virtual machines" az vm list -d --output table | eval "$LOG_PIPE"
      ;;
    webapps)
      section "Web Apps" | eval "$LOG_PIPE"
      run_az "web apps" az webapp list --output table | eval "$LOG_PIPE"
      ;;
    plans)
      section "App Service Plans" | eval "$LOG_PIPE"
      run_az "app service plans" az appservice plan list --output table | eval "$LOG_PIPE"
      ;;
    storage)
      section "Storage Accounts" | eval "$LOG_PIPE"
      run_az "storage accounts" az storage account list --output table | eval "$LOG_PIPE"
      ;;
    sql)
      section "SQL Servers" | eval "$LOG_PIPE"
      run_az "SQL servers" az sql server list --output table | eval "$LOG_PIPE"
      ;;
    vaults)
      section "Key Vaults" | eval "$LOG_PIPE"
      run_az "key vaults" az keyvault list --output table | eval "$LOG_PIPE"
      ;;
    roles)
      section "Role Assignments for Current User" | eval "$LOG_PIPE"
      USER_OBJ_ID=$(az ad signed-in-user show --query objectId -o tsv 2>/dev/null || echo "")
      if [[ -n "$USER_OBJ_ID" ]]; then
        run_az "role assignments for current user" az role assignment list --assignee "$USER_OBJ_ID" --output table | eval "$LOG_PIPE"
      else
        echo -e "${YELLOW}[WARN] Could not fetch signed-in user info (possibly missing permissions)${NC}" | eval "$LOG_PIPE"
      fi
      ;;
    esac
  done
done

end_time=$(date)
echo -e "\n${GREEN}Survey complete.${NC} Started: $start_time | Ended: $end_time" | eval "$LOG_PIPE"

