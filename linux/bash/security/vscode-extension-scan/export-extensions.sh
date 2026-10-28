#!/usr/bin/env bash
set -euo pipefail

OUT="./vscode-audit"
EXT_DIR="${VSCODE_EXTENSIONS_DIR:-$HOME/.vscode/extensions}"
EXT_FILE=""

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Export the installed VS Code extension inventory.

Options:
  -f, --extensions-file  FILE  Inventory output filename. (default: extensions.txt in output directory)
  -e, --extensions-dir   DIR   VS Code extensions directory. (default: ${EXT_DIR})
  -o, --output-dir       DIR   Output directory (default: ${OUT})
  -h, --help                   Show this help message

Environment:
  VSCODE_EXTENSIONS_DIR        Override the default extensions directory

Examples:
  ${0##*/}
  ${0##*/} -o ./audit
  ${0##*/} -e "$HOME/.vscode-insiders/extensions"
  ${0##*/} -f installed.txt -o ./audit
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -f|--extensions-file)
      if [[ $# -lt 2 || -z "$2" ]]; then
        echo "[ERROR] $1 requires a filename." >&2
        usage >&2
        exit 2
      fi
      EXT_FILE="$2"
      shift 2
      ;;
    -e|--extensions-dir)
      if [[ $# -lt 2 || -z "$2" ]]; then
        echo "[ERROR] $1 requires a directory." >&2
        usage >&2
        exit 2
      fi
      EXT_DIR="$2"
      shift 2
      ;;
    -o|--output-dir)
      if [[ $# -lt 2 || -z "$2" ]]; then
        echo "[ERROR] $1 requires a directory." >&2
        usage >&2
        exit 2
      fi
      OUT="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "[ERROR] Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      echo "[ERROR] Unexpected argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ $# -gt 0 ]]; then
  echo "[ERROR] Unexpected argument: $1" >&2
  usage >&2
  exit 2
fi

# Resolve paths before doing any directory changes.
[[ "$OUT" = /* ]] || OUT="$PWD/$OUT"
[[ "$EXT_DIR" = /* ]] || EXT_DIR="$PWD/$EXT_DIR"

if [[ -z "$EXT_FILE" ]]; then
  EXT_FILE="$OUT/extensions.txt"
elif [[ "$EXT_FILE" != /* ]]; then
  EXT_FILE="$OUT/$EXT_FILE"
fi

THIS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

if ! command -v code >/dev/null 2>&1; then
  echo "[ERROR] 'code' CLI not found in PATH." >&2
  exit 1
fi

if [[ ! -d "$EXT_DIR" ]]; then
  echo "[ERROR] Extension directory not found: $EXT_DIR" >&2
  exit 1
fi

mkdir -p "$OUT"
mkdir -p "$(dirname -- "$EXT_FILE")"

echo "[INFO] Exporting extension inventory"
code --list-extensions --show-versions | sort > "$EXT_FILE"

printf '%s\n' "$EXT_DIR" > "$OUT/extensions-path.txt"

echo "[INFO] Inventory saved to: $EXT_FILE"
echo "[INFO] Extension directory: $EXT_DIR"
echo "[INFO] Done."
