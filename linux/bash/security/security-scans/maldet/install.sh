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
  --version                  VERSION  Upstream release tag to install. Default: v2.0.1
  --accept-upstream-install           Accept upstream installation effects.
  --output-dir               DIR      Installer report parent directory. Default: /var/log/security-scans/maldet
  --dry-run                           Print the plan without installing, downloading, or writing files.
  -h, --help                          Show help.

Behavior:
  - Automatically elevate through sudo when needed
  - Install missing prerequisites from enabled repositories
  - Download the selected upstream release with Git
  - Record the resolved commit and installer checksum
  - Execute upstream install.sh
  - Remove temporary source files afterward
  - Skip installation when a supported LMD 2.x installation exists

Important upstream installation effects:
  - Installs under /usr/local/maldetect
  - Installs scheduled jobs and service integration
  - May enable the Maldet service
  - Downloads signatures
  - May modify system ClamAV signature directories and reload clamd

This is not an on-demand-only installation.
The scan wrapper does not control independent automatic jobs.

Examples:
  ./install.sh --dry-run
  ./install.sh --accept-upstream-install
  ./install.sh --version v2.0.1 --accept-upstream-install
EOF
}

# renovate: datasource=github-releases depName=rfxn/linux-malware-detect
VERSION=v2.0.1
OUTPUT_DIR=/var/log/security-scans/maldet
ACCEPT=0
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
  --version | --output-dir)
    md_need_value "$@"

    case "$1" in
    --version) VERSION="$2" ;;
    --output-dir) OUTPUT_DIR="$2" ;;
    esac

    shift 2
    ;;

  --accept-upstream-install)
    ACCEPT=1
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
    md_die "Unknown option: $1"
    ;;
  esac
done

md_require_linux
md_prepare_path
unset LMD_BASEDIR

[[ "$VERSION" =~ ^v2\.[0-9]+\.[0-9]+$ ]] ||
  md_die "--version must be an LMD 2.x release tag such as v2.0.1."

OUTPUT_DIR="$(md_absolute_path "$OUTPUT_DIR")"

if md_have maldet; then
  md_find_binary
  md_require_v2

  md_log "A supported Maldet installation is already available."
  md_log "Command: $MALDET_BIN"
  md_log "No installation or program upgrade performed."
  exit 0
fi

[[ ! -e /usr/local/maldetect ]] ||
  md_die "/usr/local/maldetect exists, but maldet is not on PATH. Review the existing installation."

REPOSITORY=https://github.com/rfxn/linux-malware-detect.git

REQUIRED_COMMANDS=(
  git
  bash
  awk
  sed
  grep
  find
  sort
  stat
  sha256sum
  md5sum
  tar
  gzip
  wget
  curl
  ps
  file
  strings
  flock
)

MISSING_COMMANDS=()

for dependency in "${REQUIRED_COMMANDS[@]}"; do
  if ! md_have "$dependency"; then
    MISSING_COMMANDS+=("$dependency")
  fi
done

PACKAGE_MANAGER=
PACKAGES=()

if [[ ${#MISSING_COMMANDS[@]} -gt 0 ]]; then
  if md_have apt-get; then
    PACKAGE_MANAGER=apt
    PACKAGES=(
      git bash coreutils findutils grep sed gawk
      tar gzip wget curl ca-certificates
      procps file binutils util-linux
    )

  elif md_have dnf; then
    PACKAGE_MANAGER=dnf
    PACKAGES=(
      git bash coreutils findutils grep sed gawk
      tar gzip wget curl ca-certificates
      procps-ng file binutils util-linux
    )

  elif md_have yum; then
    PACKAGE_MANAGER=yum
    PACKAGES=(
      git bash coreutils findutils grep sed gawk
      tar gzip wget curl ca-certificates
      procps-ng file binutils util-linux
    )

  elif md_have zypper; then
    PACKAGE_MANAGER=zypper
    PACKAGES=(
      git bash coreutils findutils grep sed gawk
      tar gzip wget curl ca-certificates
      procps file binutils util-linux
    )

  elif md_have pacman; then
    PACKAGE_MANAGER=pacman
    PACKAGES=(
      git bash coreutils findutils grep sed gawk
      tar gzip wget curl ca-certificates
      procps-ng file binutils util-linux
    )

  elif md_have apk; then
    PACKAGE_MANAGER=apk
    PACKAGES=(
      git bash coreutils findutils grep sed gawk
      tar gzip wget curl ca-certificates
      procps file binutils util-linux
    )

  else
    md_die "Missing prerequisites and no supported package manager found: ${MISSING_COMMANDS[*]}"
  fi
fi

install_dependencies() {
  case "$PACKAGE_MANAGER" in
  apt)
    apt-get update
    apt-get install -y "${PACKAGES[@]}"
    ;;
  dnf)
    dnf install -y "${PACKAGES[@]}"
    ;;
  yum)
    yum install -y "${PACKAGES[@]}"
    ;;
  zypper)
    zypper --non-interactive install "${PACKAGES[@]}"
    ;;
  pacman)
    pacman -S --needed --noconfirm "${PACKAGES[@]}"
    ;;
  apk)
    apk add "${PACKAGES[@]}"
    ;;
  "")
    return 0
    ;;
  *)
    md_die "Unsupported package manager: $PACKAGE_MANAGER"
    ;;
  esac
}

if [[ "$DRY_RUN" -eq 1 ]]; then
  if [[ ${#MISSING_COMMANDS[@]} -gt 0 ]]; then
    md_log "Missing commands: ${MISSING_COMMANDS[*]}"
    md_log "Would install prerequisites using: $PACKAGE_MANAGER"
    md_log "Packages: ${PACKAGES[*]}"
  else
    md_log "Required commands are already available."
  fi

  md_log "Would create a temporary source directory."
  md_print_command git clone \
    --branch "$VERSION" \
    --depth 1 \
    --single-branch \
    "$REPOSITORY" \
    '<temporary-directory>/source'

  md_log "Would record the resolved commit and installer checksum."
  md_log "Would execute the upstream installer as root."
  md_log "Would save reports beneath: $OUTPUT_DIR"
  md_log "Upstream scheduled-job and ClamAV integration effects apply."
  exit 0
fi

[[ "$ACCEPT" -eq 1 ]] ||
  md_die "Use --accept-upstream-install to permit upstream installation effects."

if [[ "$EUID" -ne 0 ]]; then
  md_have sudo ||
    md_die "Root privileges required; sudo is unavailable."

  exec sudo -- /bin/bash "$SCRIPT_DIR/install.sh" \
    --version "$VERSION" \
    --output-dir "$OUTPUT_DIR" \
    --accept-upstream-install
fi

LOCK_DIR=/run/security-scans-maldet-install.lock
WORK_DIR=

if ! mkdir -m 0700 "$LOCK_DIR" 2>/dev/null; then
  md_die "Installer lock exists: $LOCK_DIR. Check for another installation."
fi

cleanup() {
  if [[ -n "$WORK_DIR" && -d "$WORK_DIR" ]]; then
    rm -rf -- "$WORK_DIR"
  fi

  rmdir "$LOCK_DIR" 2>/dev/null || true
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

mkdir -p "$OUTPUT_DIR"
RUN_DIR="$(mktemp -d "$OUTPUT_DIR/install.XXXXXXXX")"

if [[ ${#MISSING_COMMANDS[@]} -gt 0 ]]; then
  md_log "Installing prerequisites."
  md_log "Dependency report: $RUN_DIR/dependencies.log"

  ## Run directly so failure inside the function stops the installer.
  install_dependencies >"$RUN_DIR/dependencies.log" 2>&1
fi

for dependency in "${REQUIRED_COMMANDS[@]}"; do
  md_have "$dependency" ||
    md_die "Prerequisite still unavailable after installation: $dependency"
done

WORK_DIR="$(mktemp -d /tmp/security-scans-maldet.XXXXXXXX)"
SOURCE_DIR="$WORK_DIR/source"

md_log "Downloading release: $VERSION"
md_log "Download report: $RUN_DIR/download.log"

git clone \
  --branch "$VERSION" \
  --depth 1 \
  --single-branch \
  "$REPOSITORY" \
  "$SOURCE_DIR" \
  >"$RUN_DIR/download.log" 2>&1

for required_file in \
  install.sh \
  files/maldet \
  files/conf.maldet \
  files/internals/pkg_lib.sh; do
  [[ -f "$SOURCE_DIR/$required_file" ]] ||
    md_die "Downloaded source is missing: $required_file"
done

grep -Eq '^[[:space:]]*lmd_version="2\.' \
  "$SOURCE_DIR/install.sh" ||
  md_die "Downloaded installer is not a recognized LMD 2.x installer."

{
  printf 'started_utc=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf 'repository=%s\n' "$REPOSITORY"
  printf 'release=%s\n' "$VERSION"
  printf 'commit=%s\n' "$(git -C "$SOURCE_DIR" rev-parse HEAD)"
  printf 'installer_sha256=%s\n' \
    "$(sha256sum "$SOURCE_DIR/install.sh" | awk '{print $1}')"
} >"$RUN_DIR/metadata.txt"

md_log "Running upstream installer."
md_log "Output: $RUN_DIR/output.log"

cd -- "$SOURCE_DIR"
md_capture "$RUN_DIR/output.log" 1 /bin/bash ./install.sh

if [[ "$MD_WRITER_RC" -ne 0 ]]; then
  md_die "Writing the installer report failed."
fi

if [[ "$MD_NATIVE_RC" -ne 0 ]]; then
  md_die "Upstream installation failed with code $MD_NATIVE_RC. Review $RUN_DIR/output.log"
fi

## Leave the temporary source directory before cleanup removes it.
cd /

md_find_binary
md_require_v2

printf '%s\n' "$MALDET_VERSION_OUTPUT" >"$RUN_DIR/version.txt"

md_log "Installation complete."
md_log "Reports: $RUN_DIR"
md_log "Review upstream automatic jobs before assuming on-demand-only behavior."
md_log "Next: sudo ./scan.sh --target /path/to/scan --verbose"
