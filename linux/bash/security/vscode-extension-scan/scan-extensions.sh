#!/usr/bin/env bash
set -euo pipefail

IMG_NAME="vsix-scan"
TAG="local"
EXT_FILE=""
EXT_DIR="${VSCODE_EXTENSIONS_DIR:-$HOME/.vscode/extensions}"
REPORT_OUT=""

THIS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
OUT="${THIS_DIR}/vscode-audit"

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Scan installed VS Code extensions using Docker.

Options:
  -n, --name             NAME  Docker image name (default: ${IMG_NAME})
  -t, --tag              TAG   Docker image tag (default: ${TAG})
  -f, --extensions-file  FILE  Optional exported inventory file
  -e, --extensions-dir   DIR   Extensions directory to scan (default: ${EXT_DIR})
      --output-dir       DIR   Working directory for inventory, logs, and cache. (default: ${OUT})
  -o, --output           FILE  Save JSON report to FILE and perform both scans. (default: terminal output only)
  -h, --help                   Show this help message

Environment:
  VSCODE_EXTENSIONS_DIR       Override the default extensions directory

Outputs:
  report.json                 Scanner JSON output (when --output is used)
  scan.log                    Scanner diagnostic output
  extensions.txt              Exported extension inventory
  cache/                      Persistent scanner cache

Examples:
  ${0##*/}
  ${0##*/} -e "$HOME/.vscode-insiders/extensions"
  ${0##*/} --output report.json
  ${0##*/} -o ./results/report.json
  ${0##*/} --output-dir ./audit --output ./audit/report.json
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
      IMG_NAME="$2"
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

## Resolve relative paths against the caller's current directory.
[[ "$OUT" = /* ]] || OUT="$PWD/$OUT"
[[ "$EXT_DIR" = /* ]] || EXT_DIR="$PWD/$EXT_DIR"

if [[ -n "$EXT_FILE" && "$EXT_FILE" != /* ]]; then
  EXT_FILE="$PWD/$EXT_FILE"
fi

if [[ -n "$REPORT_OUT" && "$REPORT_OUT" != /* ]]; then
  REPORT_OUT="$PWD/$REPORT_OUT"
fi

if [[ -z "$IMG_NAME" || -z "$TAG" ]]; then
  echo "[ERROR] Image name and tag must not be empty." >&2
  usage >&2
  exit 2
fi

IMG="${IMG_NAME}:${TAG}"

if ! docker image inspect "$IMG" >/dev/null 2>&1; then
  echo "[ERROR] Image not found: $IMG" >&2
  echo "Run build-container.sh first." >&2
  exit 1
fi

if [[ ! -d "$EXT_DIR" ]]; then
  echo "[ERROR] Extension directory not found: $EXT_DIR" >&2
  exit 1
fi

if [[ -n "$EXT_FILE" && ! -f "$EXT_FILE" ]]; then
  echo "[ERROR] Extensions inventory file not found: $EXT_FILE" >&2
  exit 1
fi

mkdir -p "$OUT" "$OUT/cache"

if [[ -n "$EXT_FILE" ]]; then
  DEST="$OUT/extensions.txt"

  if [[ "$(realpath -e -- "$EXT_FILE")" != "$(realpath -m -- "$DEST")" ]]; then
    cp -- "$EXT_FILE" "$DEST"
    echo "[INFO] Inventory copied to: $DEST"
  else
    echo "[INFO] Inventory already exists at destination: $DEST"
  fi
fi

run_scan() {
  docker run --rm \
    --read-only \
    --cap-drop=ALL \
    --security-opt=no-new-privileges \
    --tmpfs /tmp:rw,noexec,nosuid,size=64m \
    -e HOME=/tmp \
    -v "$EXT_DIR:/tmp/.vscode/extensions:ro" \
    -v "$OUT/cache:/tmp/.vsix-scan/cache" \
    "$IMG" \
    scan-all "$@"
}

echo "[INFO] Scanning extensions from: $EXT_DIR"

if [[ -z "$REPORT_OUT" ]]; then
  ## No output given, run scan and print results to terminal
  echo "[INFO] Printing findings to terminal."

  if run_scan; then
    echo "[INFO] Scan finished."
  else
    rc=$?
    echo "[ERROR] Scan failed (exit code $rc)." >&2
    exit "$rc"
  fi
else
  ## Output path given, report will save to a file
  mkdir -p "$(dirname -- "$REPORT_OUT")"

  echo
  echo "[ Scan findings ]"
  echo

  if run_scan; then
    echo "[INFO] Terminal scan finished."
  else
    rc=$?
    echo "[ERROR] Terminal scan failed (exit code $rc)." >&2
    exit "$rc"
  fi

  echo
  echo "[INFO] Generating JSON report: $REPORT_OUT"

  if run_scan --format json \
      > "$REPORT_OUT" \
      2> >(tee "$OUT/scan.log" >&2); then
    echo "[INFO] JSON report generated."
  else
    rc=$?
    echo "[ERROR] JSON report generation failed (exit code $rc)." >&2
    exit "$rc"
  fi

  echo "[INFO] Report saved to: $REPORT_OUT"
fi

echo "[INFO] Log saved to: $OUT/scan.log"
