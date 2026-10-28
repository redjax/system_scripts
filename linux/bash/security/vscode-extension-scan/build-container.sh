#!/usr/bin/env bash
set -euo pipefail

IMG="vsix-scan"
TAG="local"

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Build the VS Code extension scanner Docker image.

Options:
  -n, --name  NAME   Docker image name (default: ${IMG})
  -t, --tag   TAG    Docker image tag (default: ${TAG})
  -h, --help         Show this help message

Examples:
  ${0##*/}
  ${0##*/} --name my-scanner --tag latest
  ${0##*/} -n vsix-scan -t local
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

echo "[INFO] Building container: ${IMG}:${TAG}"

docker build -t "${IMG}:${TAG}" "$THIS_DIR"

echo "[INFO] Successfully built ${IMG}:${TAG}"
