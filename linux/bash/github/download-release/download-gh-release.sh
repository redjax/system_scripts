#!/usr/bin/env bash
set -euo pipefail

#######################################################
# Github release download helper (smart version)      #
#                                                     #
# Features:                                           #
#  - latest / tagged releases                         #
#  - platform detection (linux/darwin + arch)        #
#  - smart asset selection scoring                   #
#  - optional extraction                              #
#  - optional checksum verification                  #
#  - flexible output paths                           #
#######################################################

command -v jq >/dev/null || { echo "[ERROR] jq required" >&2; exit 1; }
command -v curl >/dev/null || { echo "[ERROR] curl required" >&2; exit 1; }

REPO=""
PATTERN=""
TAG="latest"
OUTPUT=""
EXTRACT=false
VERIFY=false
FORCE=false

function usage() {
cat <<EOF
Usage: $0 [OPTIONS]

Options:
  -r, --repo REPO        user-or-org/repo (required)
  -p, --pattern PATTERN  asset filter regex (optional)
  -t, --tag TAG          release tag (default: latest)
  -o, --output PATH      output file/dir (default: /tmp/<asset>)
  -f, --force            force overwrite
  --extract              extract archives (tar.gz, zip)
  --verify               verify checksum if .sha256/.sum exists
  --latest               same as default (kept for clarity)

Examples:
  $0 -r user-or-org/repo
  $0 -r user-or-org/repo -t v1.2.3
  $0 -r user-or-org/repo -p 'linux.*amd64' --extract --force
  $0 -r user-or-org/repo --latest --verify -o /usr/local/bin/asset
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -r|--repo)
      REPO="$2"
      shift
      ;;
    -p|--pattern)
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
    -f|--force)
      FORCE=true
      shift
      ;;
    --extract)
      EXTRACT=true
      shift
      ;;
    --verify)
      VERIFY=true
      shift
      ;;
    --latest)
      TAG="latest"
      shift
      ;;
    -h|--help)
      usage; exit 0
      ;;
    *)
      echo "[ERROR] unknown arg: $1" >&2; exit 1 ;;
  esac
  shift
done

[[ -z "$REPO" ]] && { echo "[ERROR] repo required" >&2; exit 1; }

API="https://api.github.com/repos/${REPO}"
if [[ "$TAG" == "latest" ]]; then
  URL="${API}/releases/latest"
else
  URL="${API}/releases/tags/${TAG}"
fi

echo "[INFO] Fetching $URL" >&2

JSON=$(curl -sL "$URL")

## Detect platform
OS="$(uname | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"

case "$ARCH" in
  x86_64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
esac

PLATFORM_HINTS=(
  "$OS"
  "$ARCH"
  "${OS}_${ARCH}"
  "${OS}-${ARCH}"
)

## Extract assets
ASSETS=$(echo "$JSON" | jq -r '.assets[] | "\(.name)\t\(.browser_download_url)"')

BEST_SCORE=-1
MATCHED_NAME=""
MATCHED_URL=""

## Score-based asset matching:
#  - pattern match: +50
#  - platform hint matches: +20 each
#  - otherwise score = 0
function score_asset() {
  local name="$1"
  local score=0

  ## Match pattern
  if [[ -n "$PATTERN" ]] && echo "$name" | grep -E "$PATTERN" >/dev/null 2>&1; then
    score=$((score + 50))
  fi

  ## Match platform hints
  for hint in "${PLATFORM_HINTS[@]}"; do
    if echo "$name" | grep -qi "$hint"; then
      score=$((score + 20))
    fi
  done

  ## Default preference
  if [[ $score -eq 0 ]]; then
    if echo "$name" | grep -Ei 'linux' >/dev/null; then
      score=5
    fi
  fi

  echo "$score"
}

while IFS=$'\t' read -r name url; do
  [[ -z "$name" ]] && continue

  s=$(score_asset "$name")

  if [[ $s -gt $BEST_SCORE ]]; then
    BEST_SCORE=$s
    MATCHED_NAME="$name"
    MATCHED_URL="$url"
  fi
done <<< "$ASSETS"

if [[ -z "$MATCHED_URL" ]]; then
  echo "[ERROR] No suitable asset found" >&2
  exit 1
fi

echo "[INFO] Selected: $MATCHED_NAME" >&2
echo "[INFO] Asset match confidence score: $BEST_SCORE" >&2

## Output handling
if [[ -z "$OUTPUT" ]]; then
  OUTPUT="/tmp/${MATCHED_NAME}"
fi

if [[ -f "$OUTPUT" ]]; then
  echo "[WARNING] Output file already exists: $OUTPUT"
  if [[ "$FORCE" == "false" ]]; then
    read -n 1 -r -p "Overwrite existing file? [y/N] " answer
    echo

    case "$answer" in
      [Yy]*)
        :
        ;;
      *)
        echo "[WARNING] Cancelling download, use --force to overwrite"
        exit 0
        ;;
    esac
  fi
fi

mkdir -p "$(dirname "$OUTPUT")"

echo "[INFO] Downloading → $OUTPUT" >&2

curl -L "$MATCHED_URL" -o "$OUTPUT"

## Verify checksum
if [[ "$VERIFY" == "true" ]]; then
  echo "[INFO] Checking for checksum asset" >&2

  ## Download checksum
  CHECKSUM=$(echo "$JSON" | jq -r '.assets[] | select(.name|test("sha256|checksum|\\.sum"; "i")) | .browser_download_url' | head -n1)

  if [[ -n "$CHECKSUM" ]]; then
    TMP_SUM=$(mktemp)
    curl -L "$CHECKSUM" -o "$TMP_SUM"

    echo "[INFO] Verifying checksum" >&2
    (cd "$(dirname "$OUTPUT")" && sha256sum -c "$TMP_SUM") || {
      echo "[ERROR] checksum failed" >&2
      exit 1
    }
  else
    echo "[WARN] No checksum asset found" >&2
  fi
fi

## Extract
if [[ "$EXTRACT" == "true" ]]; then
  echo "[INFO] Extracting $OUTPUT" >&2

  case "$OUTPUT" in
    *.tar.gz|*.tgz)
      tar -xzf "$OUTPUT" -C "$(dirname "$OUTPUT")"
      ;;
    *.zip)
      unzip -o "$OUTPUT" -d "$(dirname "$OUTPUT")"
      ;;
    *)
      echo "[WARN] Unknown archive format: $OUTPUT" >&2
      ;;
  esac
fi
