#!/bin/bash

SCAN_PATH="."
OUTPUT_FORMAT=""
MIN_SEVERITY=""
IGNORE_DEV=false
OFFLINE=false
DRY_RUN=false

function show_help() {
    echo ""
    echo " | run-osv-scan.sh HELP |"
    echo "  Usage: $0 [-p PATH] [-f FORMAT] [-s SEVERITY] [--ignore-dev] [--offline] [--dry-run]"
    echo ""
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--path)
      SCAN_PATH="$2"
      shift 2
      ;;
    -f|--format)
      OUTPUT_FORMAT="$2"
      shift 2
      ;;
    -s|--min-severity)
      MIN_SEVERITY="$2"
      shift 2
      ;;
    --ignore-dev)
      IGNORE_DEV=true
      shift
      ;;
    --offline)
      OFFLINE=true
      shift
      ;;
    --dry-run)
        DRY_RUN=true
        shift
        ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      show_help
      exit 1
      ;;
  esac
done

if [[ -z $SCAN_PATH ]] || [[ "$SCAN_PATH" == "" ]]; then
  echo "[WARNING] No scan path provided. Defaulting to ./"
  SCAN_PATH="."
fi

## Expand scan path
SCAN_PATH=$(realpath "$SCAN_PATH")
echo "[DEBUG] Scan path: ${SCAN_PATH}"

CMD=(osv-scanner scan source -r "$SCAN_PATH")

if [[ -n $OUTPUT_FORMAT ]]; then
  CMD+=(--format "$OUTPUT_FORMAT")
fi

if [[ -n $MIN_SEVERITY ]]; then
  CMD+=(--min-severity "$MIN_SEVERITY")
fi

if [[ $IGNORE_DEV == true ]]; then
  CMD+=(--ignore-dev)
fi

if [[ $OFFLINE == true ]]; then
  CMD+=(--offline)
fi

if [[ $DRY_RUN == true ]]; then
  echo "[DRY RUN] Would run command:"
  echo "  $> ${CMD[*]}"
  exit 0
else
  echo "[INFO] Running command:"
  echo "  $> ${CMD[*]}"
  "${CMD[@]}"

  if [[ $? -ne 0 ]]; then
    echo "[ERROR] Failed to run osv-scanner"
    exit 1
  else
    echo "[INFO] Finished running osv-scanner"
  fi
fi
