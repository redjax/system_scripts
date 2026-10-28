#!/usr/bin/env bash
set -euo pipefail

IMG_NAME="vsix-scan"
TAG="local"
EXT_FILE=""
EXT_DIR="${VSCODE_EXTENSIONS_DIR:-$HOME/.vscode/extensions}"

THIS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
OUT="${THIS_DIR}/vscode-audit"

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Scan installed VS Code extensions using Docker.

Options:
  -n, --name             NAME  Docker image name (default: vsix-scan)
  -t, --tag              TAG   Docker image tag (default: local)
  -f, --extensions-file  FILE  Optional exported inventory file
  -e, --extensions-dir   DIR   Extensions directory to scan. (default: ${EXT_DIR})
  -o, --output-dir       DIR   Report output directory. (default: ${OUT})
  -h, --help                   Show this help message

Environment:
  VSCODE_EXTENSIONS_DIR       Override the default extensions directory

Outputs:
  report.json                 Scanner JSON output
  scan.log                    Scanner diagnostic output
  cache/                      Persistent scanner cache

Examples:
  ${0##*/}
  ${0##*/} -e "$HOME/.vscode-insiders/extensions"
  ${0##*/} -f ./vscode-audit/extensions.txt -o ./results
  ${0##*/} --output-dir /tmp/extension-audit
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

## Resolve relative paths against the caller's current directory.
[[ "$OUT" = /* ]] || OUT="$PWD/$OUT"
[[ "$EXT_DIR" = /* ]] || EXT_DIR="$PWD/$EXT_DIR"

if [[ -n "$EXT_FILE" && "$EXT_FILE" != /* ]]; then
  EXT_FILE="$PWD/$EXT_FILE"
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

mkdir -p "$OUT/cache"

if [[ -n "$EXT_FILE" ]]; then
  DEST="$OUT/extensions.txt"

  if [[ "$(realpath -e -- "$EXT_FILE")" != "$(realpath -m -- "$DEST")" ]]; then
    cp -- "$EXT_FILE" "$DEST"
    echo "[INFO] Inventory copied to: $DEST"
  else
    echo "[INFO] Inventory already exists at destination: $DEST"
  fi
fi

echo "[INFO] Scanning extensions from: $EXT_DIR"
echo "[INFO] Writing report to: $OUT/report.json"

set +e
docker run --rm \
  --read-only \
  --cap-drop=ALL \
  --security-opt=no-new-privileges \
  --tmpfs /tmp:rw,noexec,nosuid,size=64m \
  -e HOME=/tmp \
  -e FORCE_COLOR=1 \
  -v "$EXT_DIR:/tmp/.vscode/extensions:ro" \
  -v "$OUT/cache:/tmp/.vsix-scan/cache" \
  "$IMG" \
  scan-all --format json \
  2> >(tee "$OUT/scan.log" >&2) \
  | tee "$OUT/report.json"

status=( "${PIPESTATUS[@]}" )
set -e

if [[ "${status[0]}" -ne 0 ]]; then
  echo "[ERROR] Docker scan failed (exit code ${status[0]})." >&2
  exit "${status[0]}"
fi

if [[ "${status[1]}" -ne 0 ]]; then
  echo "[ERROR] Failed writing the report (exit code ${status[1]})." >&2
  exit "${status[1]}"
fi

echo "[INFO] Scan finished."
echo "[INFO] Report saved to: $OUT/report.json"
echo "[INFO] Log saved to: $OUT/scan.log"
