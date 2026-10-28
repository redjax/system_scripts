#!/usr/bin/env bash
set -euo pipefail

IMG="vsix-scan"
TAG="local"
OUT="./vscode-audit"
EXT_DIR="${VSCODE_EXTENSIONS_DIR:-$HOME/.vscode/extensions}"
EXT_FILE="extensions.txt"
REPORT_OUT=""

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Build the scanner image, export installed VS Code extensions, and scan them.

Options:
  -n, --name             NAME  Docker image name (default: ${IMG})
  -t, --tag              TAG   Docker image tag (default: ${TAG})
  -f, --extensions-file  FILE  Inventory filename (default: ${EXT_FILE})
  -e, --extensions-dir   DIR   VS Code extensions directory (default: ${EXT_DIR})
      --output-dir       DIR   Output directory (default: ${OUT})
  -o, --output           FILE  Save JSON report to FILE and perform both scans. (default: terminal output only)
  -h, --help                   Show this help message

Environment:
  VSCODE_EXTENSIONS_DIR       Override the default extensions directory

Outputs:
  extensions.txt              Exported extension inventory
  extensions-path.txt         Source extension directory
  report.json                 Scanner JSON report (when --output is used)
  scan.log                    Scanner diagnostic output
  cache/                      Persistent scanner cache

Examples:
  ${0##*/}
  ${0##*/} --name my-scanner --tag dev
  ${0##*/} -e "$HOME/.vscode-insiders/extensions"
  ${0##*/} -o ./vscode-audit/report.json
  ${0##*/} --output-dir ./audit --output ./audit/report.json
  ${0##*/} -n my-scanner -t dev -f installed.txt -e "$HOME/.vscode/extensions" --output ./audit/report.json
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--name)
      if [[ $# -lt 2 || -z "$2" ]]; then
        echo "[ERROR] $1 requires an image name." >&2
        usage >&2
        exit 2
      fi
      IMG="$2"
      shift 2
      ;;
    -t|--tag)
      if [[ $# -lt 2 || -z "$2" ]]; then
        echo "[ERROR] $1 requires a tag." >&2
        usage >&2
        exit 2
      fi
      TAG="$2"
      shift 2
      ;;
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
    --output-dir)
      if [[ $# -lt 2 || -z "$2" ]]; then
        echo "[ERROR] $1 requires a directory." >&2
        usage >&2
        exit 2
      fi
      OUT="$2"
      shift 2
      ;;
    -o|--output)
      if [[ $# -lt 2 || -z "$2" ]]; then
        echo "[ERROR] $1 requires a report filename." >&2
        usage >&2
        exit 2
      fi
      REPORT_OUT="$2"
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

THIS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

## Resolve relative paths before calling scripts that may change directories.
[[ "$OUT" = /* ]] || OUT="$PWD/$OUT"
[[ "$EXT_DIR" = /* ]] || EXT_DIR="$PWD/$EXT_DIR"

## Pass only the filename to the exporter when it is relative.
if [[ "$EXT_FILE" = /* ]]; then
  INVENTORY_FILE="$EXT_FILE"
else
  INVENTORY_FILE="$OUT/$EXT_FILE"
fi

if [[ -n "$REPORT_OUT" && "$REPORT_OUT" != /* ]]; then
  REPORT_OUT="$PWD/$REPORT_OUT"
fi

BUILD_SCRIPT="$THIS_DIR/build-container.sh"
EXPORT_SCRIPT="$THIS_DIR/export-extensions.sh"
SCAN_SCRIPT="$THIS_DIR/scan-extensions.sh"

for script in "$BUILD_SCRIPT" "$EXPORT_SCRIPT" "$SCAN_SCRIPT"; do
  if [[ ! -x "$script" ]]; then
    echo "[ERROR] Script missing or not executable: $script" >&2
    echo "Run chmod +x on the script files." >&2
    exit 1
  fi
done

mkdir -p "$OUT"

echo
echo "[ Build container ]"
echo

if ! "$BUILD_SCRIPT" --name "$IMG" --tag "$TAG"; then
  echo "[ERROR] Failed building Docker script" >&2
  exit 1
fi

echo
echo "[ Export extensions ]"
echo

if ! "$EXPORT_SCRIPT" \
  --extensions-file "$INVENTORY_FILE" \
  --extensions-dir "$EXT_DIR" \
  --output-dir "$OUT"; then
  echo "[ERROR] Failed exporting VSCode extensions list." >&2
  exit 1
fi

echo
echo "[ Scan extensions ]"
echo

SCAN_ARGS=(
  --name "$IMG"
  --tag "$TAG"
  --extensions-file "$INVENTORY_FILE"
  --extensions-dir "$EXT_DIR"
  --output-dir "$OUT"
)

if [[ -n "$REPORT_OUT" ]]; then
  SCAN_ARGS+=(--output "$REPORT_OUT")
fi

if ! "$SCAN_SCRIPT" "${SCAN_ARGS[@]}"; then
  echo "[ERROR] Failed scanning VSCode extensions." >&2
  exit 1
fi

echo
echo "[INFO] Finished scanning VSCode extensions for vulnerabilities."
echo "[INFO] Inventory: $INVENTORY_FILE"

if [[ -n "$REPORT_OUT" ]]; then
  echo "[INFO] Report:    $REPORT_OUT"
fi

echo "[INFO] Log:       $OUT/scan.log"
