#!/usr/bin/env bash
set -euo pipefail
umask 077

############################################################################
# Quick-run scan entrypoint                                                #
#                                                                          #
# Constructs a predefined call to run-scan.sh. Uses my preferred defaults. #
# Scanners must be installed before running.                               #
#                                                                          #
# The idea for this script is a quick and simple entrypoint I can call     #
# on each of my machines to run the scan suite with default values.        #
############################################################################

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ORCHESTRATOR="$SCRIPT_DIR/run-scans.sh"

log() {
  printf '[easy-scan] %s\n' "$*" >&2
}

die() {
  log "ERROR: $*"
  exit 2
}

absolute_path() {
  case "$1" in
  /*) printf '%s\n' "$1" ;;
  *) printf '%s/%s\n' "$PWD" "$1" ;;
  esac
}

escape_regex() {
  printf '%s\n' "$1" |
    sed 's/[][\\.^$*+?(){}|]/\\&/g'
}

usage() {
  cat <<'EOF'
Usage: easy-scan.sh [options]

Run the configured security-scanning preset.

Options:
  --dry-run   Print the orchestration plan without running scans
  --verbose   Stream scanner output
  -h, --help  Show help

Edit the configuration section in this script to change the preset.

Defaults:
  - Select all platform-supported adapters
  - Elevate adapter commands through the orchestrator
  - Scan existing configured home/application directories
  - Run host scanners once
  - Use Trivy filesystem mode with vulnerability scanning
  - Do not initialize baselines or run separate updater scripts

Run as your normal user, not through sudo.

"All scanners" does not mean "every file on every filesystem."
Selected adapters must already be installed and configured.
EOF
}

##############################################################################
# Configuration: edit these defaults for your fleet.                         #
#                                                                            #
# Empty means --all, allowing the orchestrator to select supported adapters. #
# Example override:                                                          #
#   SCANNERS="clamav,lynis,trivy"                                            #
##############################################################################

SCANNERS=""

USE_SUDO=1
VERBOSE=0

## File scanners share these targets.
#  Missing directories are skipped; symlinked entries are skipped.
TARGET_CANDIDATES=(
  "$HOME"
  /etc
  /usr/local
  /opt
  /srv
  /var/www
)

## Keep batch reports outside the default scan targets.
OUTPUT_DIR="/var/tmp/security-scans-$(id -u)/reports"

## Must match the database used by freshclam-update.sh.
CLAMAV_DATABASE="${XDG_CACHE_HOME:-$HOME/.cache}/security-scans/clamav/db"

## Directory exclusions apply only to ClamAV.
CLAMAV_EXCLUDES=(
  '(^|/)\.git(/|$)'
  '(^|/)node_modules(/|$)'
  '(^|/)\.cache(/|$)'
  '(^|/)\.nox(/|$)'
  '(^|/)\.tox(/|$)'
  '(^|/)\.venv(/|$)'
)

MALDET_ENGINE=native

## Leave empty to use Lynis's installed defaults.
LYNIS_BIN=""
LYNIS_PROFILE=""

TRIVY_MODE=filesystem
TRIVY_SCANNERS=vuln
TRIVY_SEVERITY=UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL
TRIVY_TIMEOUT=30m
TRIVY_IGNORE_UNFIXED=0

## Leave empty to use the adapter's defaults.
TRIVY_BIN=""
TRIVY_CONFIG=""
TRIVY_IGNOREFILE=""
TRIVY_CACHE_DIR=""

TRIVY_SKIP_DIRS=(
  '**/.git'
  '**/node_modules'
  '**/.cache'
  '**/.nox'
  '**/.tox'
  '**/.venv'
  /var/lib/docker
  /var/lib/containerd
)

## Argument handling

DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
  --dry-run)
    DRY_RUN=1
    shift
    ;;

  --verbose)
    VERBOSE=1
    shift
    ;;

  -h | --help)
    usage
    exit 0
    ;;

  *)
    die "Unknown option: $1. Use run-scans.sh for custom scan flags."
    ;;
  esac
done

PLATFORM="$(uname -s)"

case "$PLATFORM" in
Linux | Darwin) ;;
*)
  die "Unsupported platform: $PLATFORM"
  ;;
esac

[[ -f "$ORCHESTRATOR" ]] ||
  die "Orchestrator not found: $ORCHESTRATOR"

## Preserve the original user's HOME, cache, executable paths, and identity.
if [[ "$EUID" -eq 0 &&
  -n "${SUDO_USER:-}" &&
  "$SUDO_USER" != root ]]; then
  die "Run ./easy-scan.sh without sudo. It requests elevation through run-scans.sh."
fi

[[ "$TRIVY_MODE" == filesystem || "$TRIVY_MODE" == rootfs ]] ||
  die "This filesystem preset does not support Trivy image mode."

if [[ "$PLATFORM" == Darwin && "$TRIVY_MODE" == rootfs ]]; then
  die "Trivy rootfs mode is not enabled on macOS."
fi

OUTPUT_DIR="$(absolute_path "$OUTPUT_DIR")"
CLAMAV_DATABASE="$(absolute_path "$CLAMAV_DATABASE")"

## Refuse existing symlinked or foreign-owned output path components
#  below /var/tmp. /var itself may be a platform-managed symlink.
if [[ "$OUTPUT_DIR" == /var/tmp/* ]]; then
  CHECK_PATH="$OUTPUT_DIR"

  while [[ "$CHECK_PATH" != /var/tmp ]]; do
    [[ ! -L "$CHECK_PATH" ]] ||
      die "Output path contains a symlink: $CHECK_PATH"

    if [[ -e "$CHECK_PATH" ]]; then
      [[ -d "$CHECK_PATH" && -O "$CHECK_PATH" ]] ||
        die "Output path must contain only directories owned by this user: $CHECK_PATH"
    fi

    CHECK_PATH="$(dirname -- "$CHECK_PATH")"
  done
fi

## Resolve scanner selection and applicable options.
scanner_selected() {
  local name="$1"

  if [[ -z "$SCANNERS" ]]; then
    case "$PLATFORM:$name" in
    Linux:clamav | Linux:rkhunter | Linux:chkrootkit | \
      Linux:lynis | Linux:maldet | Linux:trivy | \
      Darwin:clamav | Darwin:lynis | Darwin:trivy)
      return 0
      ;;
    *)
      return 1
      ;;
    esac
  fi

  case ",$SCANNERS," in
  *",$name,"*) return 0 ;;
  *) return 1 ;;
  esac
}

NEEDS_TARGETS=0

if scanner_selected clamav ||
  scanner_selected maldet ||
  scanner_selected trivy; then
  NEEDS_TARGETS=1
fi

TARGETS=()

if [[ "$NEEDS_TARGETS" -eq 1 ]]; then
  for candidate in "${TARGET_CANDIDATES[@]}"; do
    candidate="$(absolute_path "$candidate")"

    if [[ ! -d "$candidate" ]]; then
      log "Skipping missing directory: $candidate"
      continue
    fi

    if [[ -L "$candidate" ]]; then
      log "Skipping symlinked target: $candidate"
      continue
    fi

    ## Avoid accidentally including the same literal target twice.
    DUPLICATE=0

    for existing_target in "${TARGETS[@]}"; do
      if [[ "$existing_target" == "$candidate" ]]; then
        DUPLICATE=1
        break
      fi
    done

    if [[ "$DUPLICATE" -eq 0 ]]; then
      TARGETS+=("$candidate")
    fi
  done

  [[ ${#TARGETS[@]} -gt 0 ]] ||
    die "None of the configured scan targets exist."
fi

## Resolve user-visible installations before adapter elevation changes PATH.
if scanner_selected lynis &&
  [[ -z "$LYNIS_BIN" ]] &&
  command -v lynis >/dev/null 2>&1; then
  LYNIS_BIN="$(command -v lynis)"
fi

if scanner_selected trivy &&
  [[ -z "$TRIVY_BIN" ]] &&
  command -v trivy >/dev/null 2>&1; then
  TRIVY_BIN="$(command -v trivy)"
fi

## Build one invocation of the orchestrator.
ARGS=(--output-dir "$OUTPUT_DIR")

if [[ -z "$SCANNERS" ]]; then
  ARGS+=(--all)
else
  ARGS+=(--scanners "$SCANNERS")
fi

if [[ "$USE_SUDO" -eq 1 && "$EUID" -ne 0 ]]; then
  ARGS+=(--sudo)
fi

if [[ "$VERBOSE" -eq 1 ]]; then
  ARGS+=(--verbose)
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  ARGS+=(--dry-run)
fi

for target in "${TARGETS[@]}"; do
  ARGS+=(--target "$target")
done

if scanner_selected clamav; then
  ARGS+=(--clamav-database "$CLAMAV_DATABASE")

  for regex in "${CLAMAV_EXCLUDES[@]}"; do
    ARGS+=(--clamav-exclude-dir "$regex")
  done

  ## Avoid scanning the signature database itself.
  DATABASE_REGEX="$(escape_regex "$CLAMAV_DATABASE")"
  ARGS+=(--clamav-exclude-dir "^${DATABASE_REGEX}(/|$)")
fi

if scanner_selected maldet; then
  ARGS+=(--maldet-engine "$MALDET_ENGINE")
fi

if scanner_selected lynis; then
  if [[ -n "$LYNIS_BIN" ]]; then
    ARGS+=(--lynis-bin "$LYNIS_BIN")
  fi

  if [[ -n "$LYNIS_PROFILE" ]]; then
    ARGS+=(--lynis-profile "$LYNIS_PROFILE")
  fi
fi

if scanner_selected trivy; then
  ARGS+=(
    --trivy-mode "$TRIVY_MODE"
    --trivy-scanners "$TRIVY_SCANNERS"
    --trivy-severity "$TRIVY_SEVERITY"
    --trivy-timeout "$TRIVY_TIMEOUT"
  )

  if [[ "$TRIVY_IGNORE_UNFIXED" -eq 1 ]]; then
    ARGS+=(--trivy-ignore-unfixed)
  fi

  if [[ -n "$TRIVY_BIN" ]]; then
    ARGS+=(--trivy-bin "$TRIVY_BIN")
  fi

  if [[ -n "$TRIVY_CONFIG" ]]; then
    ARGS+=(--trivy-config "$TRIVY_CONFIG")
  fi

  if [[ -n "$TRIVY_IGNOREFILE" ]]; then
    ARGS+=(--trivy-ignorefile "$TRIVY_IGNOREFILE")
  fi

  if [[ -n "$TRIVY_CACHE_DIR" ]]; then
    ARGS+=(--trivy-cache-dir "$TRIVY_CACHE_DIR")
  fi

  for skip_dir in "${TRIVY_SKIP_DIRS[@]}"; do
    ARGS+=(--trivy-skip-dir "$skip_dir")
  done

  ARGS+=(--trivy-skip-dir "$CLAMAV_DATABASE")
fi

log "Scanner selection: ${SCANNERS:-all platform-supported adapters}"
log "Filesystem targets: ${TARGETS[*]:-none}"
log "Reports: $OUTPUT_DIR"

if [[ "$DRY_RUN" -eq 1 ]]; then
  log "Dry run: no scans or report-directory creation."
fi

## Preserve the orchestrator's exit code and signal behavior.
exec /bin/bash "$ORCHESTRATOR" "${ARGS[@]}"
