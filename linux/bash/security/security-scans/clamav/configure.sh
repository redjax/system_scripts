#!/usr/bin/env bash
set -euo pipefail
umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

usage() {
  cat <<'EOF'
Usage: configure.sh [options]

Options:
  --database  DIR   Suite-managed signature directory
  --owner     USER  Database owner. Default: SUDO_USER, otherwise the current user
  --dry-run         Show planned changes without modifying files or policy
  -h, --help        Show help

Default database:
  ${XDG_CACHE_HOME:-$HOME/.cache}/security-scans/clamav/db

Behavior:
  - Create the database directory if missing
  - Verify ownership of an existing database directory
  - Configure recognized FreshClam AppArmor local includes
  - Configure antivirus_db_t labeling when SELinux is enabled

SELinux:
  Use a dedicated directory below:
    /var/lib/security-scans/

  Requires:
    semanage
    restorecon
    Installed policy providing antivirus_db_t

Examples:
  sudo ./configure.sh \
    --database /home/jack/.cache/security-scans/clamav/db \
    --owner jack

  sudo ./configure.sh \
    --database /var/lib/security-scans/clamav/db \
    --owner jack \
    --dry-run

Notes:
  Prefer invoking this through install.sh, which resolves the database
  path before elevating privileges.

  The setup handles recognized policy layouts. Unexpected policies or
  conflicting mappings produce errors rather than broadening access.

  When invoked through sudo, --database is required.
EOF
}

DRY_RUN=0
DATABASE=
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

## sudo may change HOME while SUDO_USER still identifies the original user.
#  Require an explicit database instead of mixing those two identities.
if [[ -z "$DATABASE" ]]; then
  if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != root ]]; then
    clam_die \
      "When using sudo, specify --database explicitly, or run ./install.sh as your normal user."
  fi

  DATABASE="$(clam_default_database)"
fi

PLATFORM="$(uname -s)"

case "$PLATFORM" in
Linux | Darwin) ;;
*)
  clam_die "Unsupported platform: $PLATFORM"
  ;;
esac

## Configuration needs access to system policy files on Linux.
#  The installer elevates this script, including for its read-only dry run.
if [[ "$PLATFORM" == Linux && "$EUID" -ne 0 ]]; then
  clam_die "Run Linux configuration through install.sh or sudo."
fi

DATABASE="$(clam_absolute_path "$DATABASE")"

## Remove trailing slashes, except for the filesystem root.
while [[ "$DATABASE" != / && "$DATABASE" == */ ]]; do
  DATABASE="${DATABASE%/}"
done

## Restrict policy paths to avoid injecting profile/configuration syntax.
case "$DATABASE" in
"" | / | *[!a-zA-Z0-9_./-]*)
  clam_die "Database path must contain only letters, digits, _, ., /, and -."
  ;;
esac

case "$DATABASE/" in
*//* | */./* | */../*)
  clam_die "Use a normalized absolute database path without //, /./, or /../."
  ;;
esac

id "$DATABASE_OWNER" >/dev/null 2>&1 ||
  clam_die "Unknown database owner: $DATABASE_OWNER"

OWNER_UID="$(id -u "$DATABASE_OWNER")"
OWNER_GROUP="$(id -gn "$DATABASE_OWNER")"

## Refuse symlinked existing components so policy paths match filesystem paths.
CHECK_PATH="$DATABASE"

while [[ "$CHECK_PATH" != / ]]; do
  [[ ! -L "$CHECK_PATH" ]] ||
    clam_die "Database path contains a symlink: $CHECK_PATH"

  CHECK_PATH="$(dirname -- "$CHECK_PATH")"
done

if [[ -e "$DATABASE" && ! -d "$DATABASE" ]]; then
  clam_die "Database path exists but is not a directory: $DATABASE"
fi

if [[ -d "$DATABASE" ]]; then
  if [[ "$PLATFORM" == Darwin ]]; then
    EXISTING_UID="$(stat -f '%u' "$DATABASE")"
  else
    EXISTING_UID="$(stat -c '%u' "$DATABASE")"
  fi

  [[ "$EXISTING_UID" == "$OWNER_UID" ]] ||
    clam_die "Existing database is not owned by $DATABASE_OWNER: $DATABASE"
fi

SELINUX_ACTIVE=0
APPARMOR_ACTIVE=0
APPARMOR_PROFILE=
APPARMOR_LOCAL=
FCONTEXTS=
SELINUX_MAPPING_EXISTS=0

if [[ "$PLATFORM" == Linux ]]; then
  if [[ -r /sys/fs/selinux/enforce ]]; then
    SELINUX_ACTIVE=1
  elif clam_have selinuxenabled && selinuxenabled; then
    SELINUX_ACTIVE=1
  fi

  if [[ -r /sys/module/apparmor/parameters/enabled ]] &&
    grep -q '^Y' /sys/module/apparmor/parameters/enabled; then
    APPARMOR_ACTIVE=1
  fi
fi

## Complete security-policy preflight before making changes.
if [[ "$SELINUX_ACTIVE" -eq 1 ]]; then
  case "$DATABASE" in
  /var/lib/security-scans/*) ;;
  *)
    clam_die \
      "SELinux is enabled. Use --database /var/lib/security-scans/clamav/db."
    ;;
  esac

  clam_have semanage ||
    clam_die \
      "SELinux setup requires semanage. Install the appropriate policycoreutils Python utilities package."

  clam_have restorecon ||
    clam_die "SELinux setup requires restorecon."

  FCONTEXTS="$(semanage fcontext -l)" ||
    clam_die "Cannot inspect SELinux file-context policy."

  if ! printf '%s\n' "$FCONTEXTS" | grep -q 'antivirus_db_t'; then
    clam_die "Installed SELinux policy does not expose antivirus_db_t."
  fi

  ## The allowed path character set leaves only literal dots to escape.
  DB_REGEX="${DATABASE//./\\.}(/.*)?"

  EXISTING_TYPES="$(
    printf '%s\n' "$FCONTEXTS" |
      awk -v expression="$DB_REGEX" '
        $1 == expression {
          count = split($NF, parts, ":")
          if (count >= 3) {
            print parts[3]
          }
        }
      '
  )"

  if [[ -n "$EXISTING_TYPES" ]]; then
    while IFS= read -r existing_type; do
      [[ "$existing_type" == antivirus_db_t ]] ||
        clam_die "Conflicting SELinux mapping exists for: $DB_REGEX"
    done <<<"$EXISTING_TYPES"

    SELINUX_MAPPING_EXISTS=1
  fi
fi

if [[ "$APPARMOR_ACTIVE" -eq 1 ]]; then
  for candidate in \
    /etc/apparmor.d/usr.bin.freshclam \
    /etc/apparmor.d/usr.sbin.freshclam; do
    if [[ -f "$candidate" ]]; then
      [[ -z "$APPARMOR_PROFILE" ]] ||
        clam_die "Multiple FreshClam profiles found; refusing to guess."

      APPARMOR_PROFILE="$candidate"
    fi
  done

  if [[ -n "$APPARMOR_PROFILE" ]]; then
    PROFILE_NAME="$(basename -- "$APPARMOR_PROFILE")"
    APPARMOR_LOCAL="/etc/apparmor.d/local/$PROFILE_NAME"
    PROFILE_NAME_REGEX="${PROFILE_NAME//./\\.}"

    INCLUDE_REGEX="^[[:space:]]*#?include[[:space:]]+"
    INCLUDE_REGEX+="(if[[:space:]]+exists[[:space:]]+)?"
    INCLUDE_REGEX+="<local/${PROFILE_NAME_REGEX}>"

    grep -Eq "$INCLUDE_REGEX" "$APPARMOR_PROFILE" ||
      clam_die \
        "FreshClam profile lacks a recognized local include: $APPARMOR_PROFILE"

    clam_have apparmor_parser ||
      clam_die "AppArmor profile found, but apparmor_parser is unavailable."

    if [[ -L "$APPARMOR_LOCAL" ]]; then
      clam_die "Refusing to edit a symlinked local profile: $APPARMOR_LOCAL"
    fi

    if [[ -e "$APPARMOR_LOCAL" && ! -f "$APPARMOR_LOCAL" ]]; then
      clam_die "Local profile path is not a regular file: $APPARMOR_LOCAL"
    fi
  else
    if [[ -r /sys/kernel/security/apparmor/profiles ]] &&
      grep -qi freshclam /sys/kernel/security/apparmor/profiles; then
      clam_die \
        "A FreshClam profile is loaded, but its source layout is unrecognized."
    fi

    clam_log "No recognized FreshClam AppArmor profile found."
  fi
fi

clam_log "Platform: $PLATFORM"
clam_log "Database: $DATABASE"
clam_log "Database owner: $DATABASE_OWNER"
clam_log "SELinux enabled: $SELINUX_ACTIVE"
clam_log "AppArmor enabled: $APPARMOR_ACTIVE"

if [[ -d "$DATABASE" ]]; then
  clam_log "Database directory already exists with the expected owner."
else
  clam_run install -d -m 0755 \
    -o "$DATABASE_OWNER" \
    -g "$OWNER_GROUP" \
    "$DATABASE"
fi

if [[ -n "$APPARMOR_PROFILE" ]]; then
  RULE_DIR="owner \"$DATABASE/\" r,"
  RULE_FILES="owner \"$DATABASE/**\" rwk,"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    clam_log "Would ensure these rules in $APPARMOR_LOCAL:"
    printf '  %s\n  %s\n' "$RULE_DIR" "$RULE_FILES"
    clam_print_command apparmor_parser -r "$APPARMOR_PROFILE"
  else
    mkdir -p /etc/apparmor.d/local

    if [[ ! -e "$APPARMOR_LOCAL" ]]; then
      install -m 0644 /dev/null "$APPARMOR_LOCAL"
    fi

    if ! grep -Fqx "$RULE_DIR" "$APPARMOR_LOCAL"; then
      printf '\n%s\n' "$RULE_DIR" >>"$APPARMOR_LOCAL"
    fi

    if ! grep -Fqx "$RULE_FILES" "$APPARMOR_LOCAL"; then
      printf '%s\n' "$RULE_FILES" >>"$APPARMOR_LOCAL"
    fi

    apparmor_parser -r "$APPARMOR_PROFILE"
    clam_log "FreshClam AppArmor profile reloaded."
  fi
fi

if [[ "$SELINUX_ACTIVE" -eq 1 ]]; then
  if [[ "$SELINUX_MAPPING_EXISTS" -eq 0 ]]; then
    clam_run semanage fcontext -a \
      -t antivirus_db_t \
      "$DB_REGEX"
  else
    clam_log "SELinux mapping already exists."
  fi

  clam_run restorecon -R -v "$DATABASE"
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  clam_log "Configuration dry run complete."
else
  clam_log "Configuration complete."
fi
