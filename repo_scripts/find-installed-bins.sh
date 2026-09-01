#!/usr/bin/env bash
set -uo pipefail

######################################
# Find bins in common/standard paths #
######################################

DEDUPE="false"

declare -a paths=(
    "/usr/local/bin"
    "/usr/bin"
    # "$HOME/.local/share/bin"
    "$HOME/.atuin/bin"
    "$HOME/.local/bin"
    "$HOME/.local/lib"
    "/usr/local/go/bin"
)

usage() {
  cat <<EOF
Usage:
  ${0##*/} [OPTIONS]
  
Options:
  -h, --help  Print this help menu
  --dedupe    Skip paths that have already been seen
EOF
}

while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      usage
      exit 0
      ;;
    --dedupe)
      DEDUPE="true"
      shift
      ;;
    *)
      echo "[ERROR] Invalid option: ${1}" >&2
      exit 1
      ;;
  esac
done

OUTPUT_FILE="$(mktemp)"

trap 'rm -f "$OUTPUT_FILE"' EXIT

{
  printf '%-12s %s\n' "TYPE" "PATH"
  printf '%-12s %s\n' "------------" "----------------------------------------"

  ## Avoid reporting the same file twice when paths overlap.
  declare -A seen

  for base in "${paths[@]}"; do
      [[ -d "$base" ]] || continue

      if [[ "$base" == "$HOME/.local/share" ]]; then
          ## Your $HOME/.local/share/**/bin paths
          while IFS= read -r -d '' dir; do
              while IFS= read -r -d '' file; do
                  [[ -f "$file" && -x "$file" ]] || continue
                  if [[ "$DEDUPE" == "true" ]]; then
                      [[ ${seen["$file"]+yes} ]] && continue
                      seen["$file"]=1
                  fi
                  printf '%-12s %s\n' "executable" "$file"
              done < <(find "$dir" -maxdepth 1 -type f -print0)
          done < <(find "$base" -type d -name bin -print0)
      elif [[ "$base" == */lib ]]; then
          ## Libraries: show the top-level contents, rather than every file
          #  inside potentially huge library trees.
          while IFS= read -r -d '' file; do
              if [[ "$DEDUPE" == "true" ]]; then
                  [[ ${seen["$file"]+yes} ]] && continue
                  seen["$file"]=1
              fi
              printf '%-12s %s\n' "library" "$file"
          done < <(find "$base" -mindepth 1 -maxdepth 1 -print0)
      else
          while IFS= read -r -d '' file; do
              [[ -f "$file" && -x "$file" ]] || continue
              if [[ "$DEDUPE" == "true" ]]; then
                  [[ ${seen["$file"]+yes} ]] && continue
                  seen["$file"]=1
              fi
              printf '%-12s %s\n' "executable" "$file"
          done < <(find "$base" -maxdepth 1 -type f -print0)
      fi
  done
} > "$OUTPUT_FILE"

less -FRX "$OUTPUT_FILE"
