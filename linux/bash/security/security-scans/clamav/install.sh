#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

usage() {
  cat << 'EOF'
Usage: install.sh [options]

Options:
  --database  DIR   Prepare this suite-managed database directory
  --owner     USER  Database owner. Default: SUDO_USER, otherwise the current user
  --dry-run         Show planned installation and configuration changes
  -h, --help        Show help

Default database:
  ${XDG_CACHE_HOME:-$HOME/.cache}/security-scans/clamav/db

Supported package managers:
  apt-get, dnf, yum, pacman, apk, zypper, brew

Behavior:
  - Install clamscan and freshclam if either is missing
  - Verify that both commands are available
  - Invoke configure.sh to prepare the database and security policy

Notes:
  Run this as your normal user. Individual Linux operations are elevated
  when needed.

  SELinux-enabled systems require a database below:
    /var/lib/security-scans/

  Linux configuration dry runs may request sudo so they can inspect
  security policy. They do not intentionally modify files or reload policy.

Examples:
  ./install.sh --dry-run

  ./install.sh

  ./install.sh \
    --database /var/lib/security-scans/clamav/db \
    --owner jack
EOF
}

ensure_apparmor_parser() {
  [[ "$(uname -s)" == Linux ]] || return 0

  ## Only request AppArmor tools when the kernel module is enabled.
  if [[ ! -r /sys/module/apparmor/parameters/enabled ]] ||
    ! grep -q '^Y' /sys/module/apparmor/parameters/enabled; then
    return 0
  fi

  ## Match the profile layouts supported by configure.sh.
  if [[ ! -f /etc/apparmor.d/usr.bin.freshclam &&
    ! -f /etc/apparmor.d/usr.sbin.freshclam ]]; then
    return 0
  fi

  if clam_have apparmor_parser; then
    clam_log "AppArmor parser is already available."
    return 0
  fi

  clam_log "FreshClam AppArmor configuration requires apparmor_parser."

  if clam_have apt-get; then
    clam_root apt-get update
    clam_root apt-get install -y apparmor

  elif clam_have zypper; then
    clam_root zypper --non-interactive install apparmor-parser

  elif clam_have pacman; then
    clam_root pacman -S --needed --noconfirm apparmor

  else
    clam_die \
      "Active FreshClam AppArmor profile found, but parser installation is not mapped for this package manager."
  fi

  if [[ "$DRY_RUN" -eq 0 ]]; then
    clam_have apparmor_parser ||
      clam_die "AppArmor package installation completed, but apparmor_parser is still unavailable."
  fi
}

DRY_RUN=0
DATABASE="$(clam_default_database)"
DATABASE_OWNER="${SUDO_USER:-$(id -un)}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --database | --owner)
      clam_need_value "$@"

      case "$1" in
        --database)
          DATABASE="$2"
          ;;
        --owner)
          DATABASE_OWNER="$2"
          ;;
      esac

      shift 2
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
      clam_die "Unknown option: $1"
      ;;
  esac
done

PLATFORM="$(uname -s)"

case "$PLATFORM" in
  Linux | Darwin) ;;
  *)
    clam_die "Unsupported platform: $PLATFORM"
    ;;
esac

DATABASE="$(clam_absolute_path "$DATABASE")"

id "$DATABASE_OWNER" > /dev/null 2>&1 ||
  clam_die "Unknown database owner: $DATABASE_OWNER"

[[ -f "$SCRIPT_DIR/configure.sh" ]] ||
  clam_die "Configuration script not found: $SCRIPT_DIR/configure.sh"

## Reject the default home-cache location before installing packages when
#  SELinux requires a dedicated system-state path.
SELINUX_ACTIVE=0

if [[ "$PLATFORM" == Linux ]]; then
  if [[ -r /sys/fs/selinux/enforce ]]; then
    SELINUX_ACTIVE=1
  elif clam_have selinuxenabled && selinuxenabled; then
    SELINUX_ACTIVE=1
  fi
fi

if [[ "$SELINUX_ACTIVE" -eq 1 ]]; then
  case "$DATABASE" in
    /var/lib/security-scans/*) ;;
    *)
      clam_die \
        "SELinux is enabled. Use --database /var/lib/security-scans/clamav/db."
      ;;
  esac
fi

ALREADY_INSTALLED=0

if clam_have clamscan && clam_have freshclam; then
  clam_log "clamscan and freshclam are already available."
  ALREADY_INSTALLED=1
fi

if [[ "$ALREADY_INSTALLED" -eq 0 ]]; then
  case "$PLATFORM" in
    Darwin)
      clam_have brew ||
        clam_die "Homebrew is required on macOS."

      [[ "$EUID" -ne 0 ]] ||
        clam_die "Run Homebrew installation as your normal user."

      clam_run brew install clamav
      ;;

    Linux)
      if clam_have apt-get; then
        clam_root apt-get update
        clam_root apt-get install -y clamav clamav-freshclam

      elif clam_have dnf; then
        ## Resolve executable providers instead of assuming RPM package names.
        clam_root dnf install -y \
          /usr/bin/clamscan \
          /usr/bin/freshclam

      elif clam_have yum; then
        clam_root yum install -y \
          /usr/bin/clamscan \
          /usr/bin/freshclam

      elif clam_have pacman; then
        ## Do not perform a database-only refresh or partial upgrade.
        clam_root pacman -S --needed --noconfirm clamav

      elif clam_have apk; then
        clam_root apk add clamav-scanner freshclam

      elif clam_have zypper; then
        clam_root zypper --non-interactive install clamav

      else
        clam_die "No supported Linux package manager found."
      fi
      ;;
  esac
fi

if [[ "$DRY_RUN" -eq 0 ]]; then
  clam_have clamscan ||
    clam_die "Installation completed, but clamscan is not on PATH."

  clam_have freshclam ||
    clam_die "Installation completed, but freshclam is not on PATH."
fi

ensure_apparmor_parser

CONFIG_ARGS=(
  --database "$DATABASE"
  --owner "$DATABASE_OWNER"
)

if [[ "$DRY_RUN" -eq 1 ]]; then
  CONFIG_ARGS+=(--dry-run)
fi

clam_log "Running database and security-policy configuration."

if [[ "$PLATFORM" == Linux && "$EUID" -ne 0 ]]; then
  clam_have sudo ||
    clam_die "Configuration requires root privileges; sudo is unavailable."

  sudo -- /bin/bash "$SCRIPT_DIR/configure.sh" "${CONFIG_ARGS[@]}"
else
  /bin/bash "$SCRIPT_DIR/configure.sh" "${CONFIG_ARGS[@]}"
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  clam_log "Installation/configuration dry run complete."
else
  clam_log "Installation and configuration complete."
  clamscan --version

  printf '[clamav] Next command:' >&2
  printf ' %q' \
    /bin/bash \
    "$SCRIPT_DIR/freshclam-update.sh" \
    --database "$DATABASE" >&2
  printf '\n' >&2
fi
