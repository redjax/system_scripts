#!/usr/bin/env bash
set -euo pipefail

_PARALLEL_MIRROR_THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

FILE="${1:-repos.txt}"
MAX_JOBS="${MAX_JOBS:-5}"

declare -a PIDS=()

function worker() {
  local url="$1"
  local dest="$2"
  local auth="$3"

  "${_PARALLEL_MIRROR_THIS_DIR}/worker.sh" "$url" "$dest" "$auth"
}

function wait_for_slot() {
  while [[ "${#PIDS[@]}" -ge "$MAX_JOBS" ]]; do
    for i in "${!PIDS[@]}"; do
      if ! kill -0 "${PIDS[$i]}" 2>/dev/null; then
        unset "PIDS[$i]"
      fi
    done
    PIDS=("${PIDS[@]}")
    sleep 0.2
  done
}

while read -r url dest auth; do
  [[ -z "$url" || "$url" == \#* ]] && continue

  wait_for_slot

  worker "$url" "$dest" "$auth" >> "logs/$(basename "$dest").log" 2>&1 &
  PIDS+=("$!")

done < "$FILE"

wait
echo "[+] Done"
