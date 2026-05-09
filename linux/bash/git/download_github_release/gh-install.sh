#!/usr/bin/env bash
set -euo pipefail

if ! command -v curl >/dev/null 2>&1; then
  echo "[ERROR] curl is not installed" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "[ERROR] jq is not installed" >&2
  exit 1
fi

if ! command -v find >/dev/null 2>&1; then
  echo "[ERROR] find is not installed" >&2
  exit 1
fi

DRY_RUN=0
OWNER=""
REPO=""
ASSET_PATTERN=""
INSTALL_DIR="$HOME/.local/bin"

## Print or run a command
function run() {
  if (( DRY_RUN )); then
    printf '[DRY-RUN] %q ' "$@"
    printf '\n'
  else
    "$@"
  fi
}

function usage() {
  echo ""
  echo "Usage: ${0} [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  -h, --help                 Print this help menu"
  echo "  -n, --dry-run              Show commands without executing them"
  echo "  --user           <string>  Repository owner name"
  echo "  --repo           <string>  Repository name"
  echo "  --asset-pattern  <string>  Custom asset name regex for non-standard package names"
  echo "  owner/repo       <string>  Positional argument, use instead of --user <username> --repo <repo-name>"
  echo ""
  echo "Examples:"
  echo "  $0 sharkdp/bat"
  echo "  $0 --user sharkdp --repo bat"
  echo "  $0 --user sharkdp --repo bat --asset-pattern 'bat-.*-x86_64-unknown-linux-gnu.tar.gz'"
  echo "  $0 -n owner/repo"
  echo ""
}

function detect_platform() {
  local os arch
  os=$(uname -s | tr '[:upper:]' '[:lower:]')
  arch=$(uname -m | tr '[:upper:]' '[:lower:]')

  case "$os" in
    linux*)
      OS="linux"
      ;;
    darwin*)
      OS="darwin"
      ;;
    msys*|mingw*|cygwin*|windows*)
      OS="windows"
      ;;
    *)
      OS="$os"
      ;;
  esac

  case "$arch" in
    x86_64|amd64)
      ARCH="amd64"
      ;;
    arm64|aarch64)
      ARCH="arm64"
      ;;
    armv7*|armv6*)
      ARCH="armv7"
      ;;
    i386|i686)
      ARCH="386"
      ;;
    *)
      ARCH="$arch"
      ;;
  esac
}

## Parse args
POSITIONAL=()
while (($#)); do
  case "$1" in
    --dry-run|-n)
      DRY_RUN=1
      shift
      ;;
    --user)
      OWNER="${2:-}"
      shift 2
      ;;
    --repo)
      REPO="${2:-}"
      shift 2
      ;;
    --asset-pattern)
      ASSET_PATTERN="${2:-}"
      shift 2
      ;;
    --install-dir|--install-path|--dest)
      INSTALL_DIR="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done

set -- "${POSITIONAL[@]}"

## owner/repo positional, if provided
if (($# >= 1)); then
  if [[ -z "$OWNER" && -z "$REPO" ]]; then
    OWNER="${1%%/*}"
    REPO="${1##*/}"
  fi
fi

if [[ -z "$OWNER" || -z "$REPO" ]]; then
  echo "Error: must specify owner and repo via owner/repo or --user/--repo." >&2
  usage

  exit 1
fi

detect_platform
echo "Detected platform: OS=${OS}, ARCH=${ARCH}"

API="https://api.github.com/repos/${OWNER}/${REPO}/releases/latest"
echo "Querying latest release for ${OWNER}/${REPO}"
JSON=$(curl -fsSL "$API")

TAG_NAME=$(jq -r '.tag_name' <<<"$JSON")
if [[ "$TAG_NAME" == "null" || -z "$TAG_NAME" ]]; then
  echo "No releases found for ${OWNER}/${REPO}" >&2
  exit 1
fi
echo "Latest release tag: $TAG_NAME"

## Select asset from pattern
if [[ -n "$ASSET_PATTERN" ]]; then
  echo "Using explicit asset pattern: $ASSET_PATTERN"
  ASSET=$(jq -r --arg re "$ASSET_PATTERN" \
    '.assets[] | select(.name | test($re)) | .name + " " + .browser_download_url' \
    <<<"$JSON" | head -n1)
else
  ## Build a heuristic pattern based on OS/ARCH and common naming schemes.
  #  This is intentionally broad; tweak as needed per repo.
  case "$OS" in
    linux)
      os_re="linux"
      ;;
    darwin)
      os_re="darwin|mac|macos|osx"
      ;;
    windows)
      os_re="windows|win"
      ;;
    *)
      os_re="$OS"
      ;;
  esac

  case "$ARCH" in
    amd64)
      arch_re="amd64|x86_64|x64"
      ;;
    arm64)
      arch_re="arm64|aarch64"
      ;;
    armv7)
      arch_re="armv7|armhf"
      ;;
    386)
      arch_re="386|x86"
      ;;
    *)
      arch_re="$ARCH"
      ;;
  esac

  ## Prefer archives over checksums, etc.
  echo "Auto-selecting asset for OS pattern /${os_re}/ and ARCH pattern /${arch_re}/"

  ASSET=$(
    jq -r --arg os_re "$os_re" --arg arch_re "$arch_re" '
      .assets[]
      | select(.name | test($os_re; "i"))
      | select(.name | test($arch_re; "i"))
      | select(.name | test("\\.(tar\\.gz|tgz|tar\\.bz2|tar\\.xz|zip|deb|rpm|exe)$"; "i"))
      | .name + " " + .browser_download_url
    ' <<<"$JSON" | head -n1
  )

  ## Fallback: if nothing matched, just take first asset.
  if [[ -z "$ASSET" ]]; then
    echo "No asset matched OS/ARCH heuristics; falling back to first asset."
    ASSET=$(jq -r '.assets[0] | .name + " " + .browser_download_url' <<<"$JSON")
  fi
fi

if [[ -z "$ASSET" || "$ASSET" == "null null" ]]; then
  echo "No matching asset found." >&2
  exit 1
fi

ASSET_NAME="${ASSET%% *}"
ASSET_URL="${ASSET#* }"
echo "Selected asset: $ASSET_NAME"
echo "Download URL: $ASSET_URL"

TMPDIR=$(mktemp -d /tmp/gh-install.XXXXXX)
trap 'rm -rf "$TMPDIR"' EXIT
ARCHIVE_PATH="${TMPDIR}/${ASSET_NAME}"

echo "Will download to: ${ARCHIVE_PATH}"
run curl -fL "$ASSET_URL" -o "$ARCHIVE_PATH"

## Extract and install
case "$ASSET_NAME" in
  *.tar.gz|*.tgz)
    if ! command -v tar >/dev/null 2>&1; then
      echo "[ERROR] tar is not installed" >&2
      exit 1
    fi

    echo "Will extract tar.gz into ${TMPDIR}"
    run tar -xzf "$ARCHIVE_PATH" -C "$TMPDIR"
    ;;
  *.tar.bz2|*.tbz2)
    if ! command -v tar >/dev/null 2>&1; then
      echo "[ERROR] tar is not installed" >&2
      exit 1
    fi

    echo "Will extract tar.bz2 into ${TMPDIR}"
    run tar -xjf "$ARCHIVE_PATH" -C "$TMPDIR"
    ;;
  *.tar.xz)
    if ! command -v tar >/dev/null 2>&1; then
      echo "[ERROR] tar is not installed" >&2
      exit 1
    fi

    echo "Will extract tar.xz into ${TMPDIR}"
    run tar -xJf "$ARCHIVE_PATH" -C "$TMPDIR"
    ;;
  *.zip)
    if ! command -v unzip >/dev/null 2>&1; then
      echo "[ERROR] unzip is not installed" >&2
      exit 1
    fi

    echo "Will extract zip into ${TMPDIR}"
    run unzip -q "$ARCHIVE_PATH" -d "$TMPDIR"
    ;;
  *.deb|*.rpm|*.exe)
    echo "Detected package/exe asset (${ASSET_NAME})."
    echo "You may want to install it with your package manager or run it manually:"
    echo "  ${ARCHIVE_PATH}"
    ;;
  *)
    echo "Treating asset as raw binary (no extraction)."
    ;;
esac

## Find candidate binary (only if archive was extracted / raw binary)
BIN_CANDIDATE=""
if compgen -G "${TMPDIR}/*" >/dev/null; then
  BIN_CANDIDATE=$(find "$TMPDIR" -maxdepth 3 -type f -executable | head -n1 || true)
fi

if [[ -z "$BIN_CANDIDATE" ]]; then
  if [[ -x "$ARCHIVE_PATH" ]]; then
    BIN_CANDIDATE="$ARCHIVE_PATH"
  fi
fi

if [[ -z "$BIN_CANDIDATE" ]]; then
  echo "Could not automatically determine binary to install." >&2
  echo "Inspect ${TMPDIR} and handle installation manually." >&2

  exit 1
fi

echo "Binary candidate: $BIN_CANDIDATE"
TARGET="${INSTALL_DIR}/$(basename "$BIN_CANDIDATE")"
echo "Will install to: $TARGET"

if ! run sudo mkdir -p "$INSTALL_DIR"; then
  LAST_EXIT=$?

  echo "[ERROR] Failed creating install dir" >&2
  exit $LAST_EXIT
fi

if ! run sudo install -m 0755 "$BIN_CANDIDATE" "$TARGET";  then
  LAST_EXIT=$?

  echo "[ERROR] Failed installing $BIN_CANDIDATE" >&2
  exit $LAST_EXIT
fi

echo "Done. Make sure ${INSTALL_DIR} is on your PATH."
if (( DRY_RUN )); then
  echo "(Dry-run mode: nothing was actually downloaded or installed.)"
fi

