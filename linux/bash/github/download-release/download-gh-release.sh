#!/usr/bin/env bash
set -euo pipefail

#######################################################
# Github release download helper.                     #
#                                                     #
# Downloads a release asset from a GitHub repository  #
# based on the specified tag and asset name pattern.  #
#######################################################

if ! command -v jq >/dev/null 2>&1; then
  echo "[ERROR] jq is not installed" >&2
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "[ERROR] curl is not installed" >&2
  exit 1
fi

## user-or-org/repo
REPO=""
## regex or substring match for asset name (optional)
PATTERN=""
## release tag (optional, defaults to "latest")
TAG="latest"
## output path (optional)
OUTPUT=""

function usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Options:
  -h, --help                                  Show this help message and exit
  -r, --repo           user-or-org/repo-name  GitHub repository in the format "user-or-org/repo" (required)
  -p, --asset-pattern  STRING                 Regex or substring to match asset name (optional)
  -t, --tag            TAG                    Release tag to download from (default: "latest")
  -o, --output         PATH                   Output directory or file path (default: /tmp/<asset-name>/)

Examples:
  $0 -r octocat/Hello-World -p "linux-amd64"
  $0 -r octocat/Hello-World -t "v1.0.0"
  $0 -r octocat/Hello-World -p "linux-amd64" -t "v1.0.0"
  $0 -r octocat/Hello-World -o "/path/to/output"
EOF
}

## Parse CLI args
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    -r|--repo)
      REPO="$2"
      shift
      ;;
    -p|--asset-pattern)
      PATTERN="$2"
      shift
      ;;
    -t|--tag)
      TAG="$2"
      shift
      ;;
    -o|--output)
      OUTPUT="$2"
      shift
      ;;
    *)
      echo "[ERROR] Invalid arg: $1" >&2
      usage
      exit 1
      ;;
  esac
  shift
done

## Validate args
if [[ -z "$REPO" ]]; then
  echo "[ERROR] Repository is required" >&2
  usage
  exit 1
fi

## Construct API URL base
API="https://api.github.com/repos/${REPO}"

## Construct release URL
if [[ "$TAG" == "latest" ]]; then
  URL="${API}/releases/latest"
else
  URL="${API}/releases/tags/${TAG}"
fi

echo "[INFO] Fetching release metadata from $URL" >&2

JSON=$(curl -sL "$URL")

## Extract name + url pairs
ASSETS=$(echo "$JSON" | jq -r '.assets[] | "\(.name) \(.browser_download_url)"')

MATCHED_NAME=""
MATCHED_URL=""

while read -r name url; do
  [[ -z "$name" ]] && continue

  if [[ -z "$PATTERN" ]]; then
    MATCHED_NAME="$name"
    MATCHED_URL="$url"
    break
  fi

  if echo "$name" | grep -E "$PATTERN" >/dev/null 2>&1; then
    MATCHED_NAME="$name"
    MATCHED_URL="$url"
    break
  fi
done <<< "$ASSETS"

if [[ -z "$MATCHED_URL" ]]; then
  echo "[ERROR] No matching asset found for pattern: $PATTERN" >&2
  exit 1
fi

## Default output path logic
if [[ -z "$OUTPUT" ]]; then
  OUTPUT="/tmp/${MATCHED_NAME}"
fi

## If output is a directory or ends with /
if [[ "$OUTPUT" == */ ]]; then
  mkdir -p "$OUTPUT"
  OUTPUT="${OUTPUT%/}/${MATCHED_NAME}"
else
  mkdir -p "$(dirname "$OUTPUT")"
fi

echo "[INFO] Downloading: $MATCHED_URL" >&2
echo "[INFO] Output: $OUTPUT" >&2

curl -L "$MATCHED_URL" -o "$OUTPUT"
