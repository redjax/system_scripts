#!/usr/bin/env bash
set -euo pipefail
umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

usage() {
  cat <<'EOF'
Usage: install.sh [options]

Options:
  --version      VERSION  Release version without leading v
  --install-dir  DIR      Destination directory. Default: /usr/local/bin
  --force                 Install even if trivy is already available
  --dry-run               Show plan without downloading or writing files
  -h, --help              Show help

Platforms:
  Linux: x86_64, aarch64/arm64
  macOS: x86_64, arm64

Behavior:
  - Download official GitHub release archive and checksums
  - Verify archive SHA-256
  - Install only the trivy binary

Requirements:
  curl, tar, and sha256sum or shasum

Checksums downloaded from the same release detect corruption but do not
independently authenticate a compromised upstream release.
EOF
}

# renovate: datasource=github-releases depName=aquasecurity/trivy
VERSION=0.76.1

INSTALL_DIR=/usr/local/bin
FORCE=0
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
  --version | --install-dir)
    tv_need_value "$@"

    case "$1" in
    --version) VERSION="$2" ;;
    --install-dir) INSTALL_DIR="$2" ;;
    esac

    shift 2
    ;;
  --force)
    FORCE=1
    shift
    ;;
  --dry-run)
    DRY_RUN=1
    shift
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    tv_die "Unknown option: $1"
    ;;
  esac
done

tv_require_platform

[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] ||
  tv_die "Use a release version such as 0.76.1."

INSTALL_DIR="$(tv_absolute_path "$INSTALL_DIR")"
DESTINATION="$INSTALL_DIR/trivy"

if tv_have trivy && [[ "$FORCE" -eq 0 ]]; then
  tv_log "Trivy is already available: $(command -v trivy)"
  tv_log "Use --force to install the pinned version."
  exit 0
fi

case "$(uname -s)" in
Linux) RELEASE_OS=Linux ;;
Darwin) RELEASE_OS=macOS ;;
esac

case "$(uname -m)" in
x86_64 | amd64) RELEASE_ARCH=64bit ;;
aarch64 | arm64) RELEASE_ARCH=ARM64 ;;
*) tv_die "Unsupported architecture for this installer: $(uname -m)" ;;
esac

ARCHIVE="trivy_${VERSION}_${RELEASE_OS}-${RELEASE_ARCH}.tar.gz"
CHECKSUMS="trivy_${VERSION}_checksums.txt"
BASE_URL="https://github.com/aquasecurity/trivy/releases/download/v${VERSION}"

if [[ "$DRY_RUN" -eq 1 ]]; then
  tv_log "Would download:"
  printf '  %s/%s\n' "$BASE_URL" "$ARCHIVE"
  printf '  %s/%s\n' "$BASE_URL" "$CHECKSUMS"
  tv_log "Would verify SHA-256 and install: $DESTINATION"
  exit 0
fi

for dependency in curl tar awk; do
  tv_have "$dependency" || tv_die "Missing dependency: $dependency"
done

if ! tv_have sha256sum && ! tv_have shasum; then
  tv_die "Install sha256sum or shasum."
fi

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/security-scans-trivy.XXXXXXXX")"
trap 'rm -rf -- "$WORK_DIR"' EXIT

tv_log "Downloading Trivy $VERSION."

curl --fail --location --show-error \
  --retry 3 --connect-timeout 20 \
  --output "$WORK_DIR/$ARCHIVE" \
  "$BASE_URL/$ARCHIVE"

curl --fail --location --show-error \
  --retry 3 --connect-timeout 20 \
  --output "$WORK_DIR/$CHECKSUMS" \
  "$BASE_URL/$CHECKSUMS"

EXPECTED="$(
  awk -v filename="$ARCHIVE" '
    $2 == filename || $2 == "*" filename {
      print $1
    }
  ' "$WORK_DIR/$CHECKSUMS"
)"

[[ "$EXPECTED" =~ ^[a-fA-F0-9]{64}$ ]] ||
  tv_die "Missing or ambiguous checksum for $ARCHIVE."

ACTUAL="$(tv_sha256 "$WORK_DIR/$ARCHIVE")"

[[ "$ACTUAL" == "$EXPECTED" ]] ||
  tv_die "Archive SHA-256 verification failed."

## Extract only the executable, not every archive member.
tar -xzf "$WORK_DIR/$ARCHIVE" -C "$WORK_DIR" trivy

[[ -f "$WORK_DIR/trivy" && ! -L "$WORK_DIR/trivy" ]] ||
  tv_die "Archive did not contain a regular trivy executable."

if [[ "$EUID" -eq 0 ]]; then
  install -d "$INSTALL_DIR"
  install -m 0755 "$WORK_DIR/trivy" "$DESTINATION"
elif [[ -d "$INSTALL_DIR" && -w "$INSTALL_DIR" ]]; then
  install -m 0755 "$WORK_DIR/trivy" "$DESTINATION"
elif [[ "$INSTALL_DIR" == "$HOME/"* ]]; then
  install -d "$INSTALL_DIR"
  install -m 0755 "$WORK_DIR/trivy" "$DESTINATION"
else
  tv_root install -d "$INSTALL_DIR"
  tv_root install -m 0755 "$WORK_DIR/trivy" "$DESTINATION"
fi

tv_log "Installed: $DESTINATION"
"$DESTINATION" --version
