#!/usr/bin/env bash

######################################
# Backup VS Code settings, keybinds, #
# and extensions for all profiles.   #
######################################

set -euo pipefail

## Default values
BACKUP_DIR="$HOME/VSCodeBackup"
RETAIN=3
TRIM=false

## Return a timestamp
timestamp() {
  date +"%Y%m%d_%H%M%S"
}

## Cleanup backups function
cleanup_backups() {
  local dir="$1"
  local retain="$2"

  echo
  echo "=== Cleanup ==="
  echo

  echo "+ Cleaning up backups in $dir (retain $retain)..."
  echo

  for pattern in "*_settings.json" "*_keybinds.json" "*_extensions.txt"; do
    # shellcheck disable=SC2207
    mapfile -t files < <(find "$dir" -maxdepth 1 -type f -name "$pattern" -printf '%T@ %p\n' 2>/dev/null | sort -r -n | awk '{print $2}')

    if (( ${#files[@]} > retain )); then
      to_delete=( "${files[@]:$retain}" )
      for f in "${to_delete[@]}"; do
        echo "  Removing: $f"
        rm -f "$f"
      done
    fi
  done
}

## Backup extensions
backup_extensions() {
  local outdir="$1"
  local profile="$2"
  local friendly_profile="$3"
  local ts
  ts=$(timestamp)
  local outfile="$outdir/${ts}_extensions.txt"

  echo "+ Backing up extensions for profile '$profile' -> $outfile"

  if [[ "$profile" == "default" ]]; then
    code --list-extensions > "$outfile"
  else
    if [[ -n "$friendly_profile" ]]; then
      code --list-extensions --profile="$friendly_profile" > "$outfile"
    else
      # Fallback: might be empty if friendly name missing
      code --list-extensions --profile="$profile" > "$outfile"
    fi
  fi
}

## Backup settings
backup_settings() {
  local source="$1"
  local outdir="$2"
  local profile="$3"
  local ts
  ts=$(timestamp)
  local dest="$outdir/${ts}_settings.json"

  if [[ -f "$source" ]]; then
    echo "+ Backing up settings for '$profile' -> $dest"
    cp "$source" "$dest"
  else
    echo "[WARNING] settings.json not found for profile '$profile'"
  fi
}

## Backup keybindings
backup_keybinds() {
  local source="$1"
  local outdir="$2"
  local profile="$3"
  local ts
  ts=$(timestamp)
  local dest="$outdir/${ts}_keybinds.json"

  if [[ -f "$source" ]]; then
    echo "+ Backing up keybindings for '$profile' -> $dest"
    cp "$source" "$dest"
  else
    echo "[WARNING] keybindings.json not found for profile '$profile'"
  fi
}

## Backup full profile
backup_profile() {
  local profile="$1"
  local profile_path="$2"
  local friendly_profile_name="${3:-}"
  local outdir="$BACKUP_DIR/$profile"

  mkdir -p "$outdir"

  echo
  echo "=== Backing up profile: $profile ==="
  echo

  if ! backup_extensions "$outdir" "$profile" "$friendly_profile_name"; then
    echo "[ERROR] Failed to backup extensions for profile '$profile'."
  fi

  if ! backup_settings "$profile_path/settings.json" "$outdir" "$profile"; then
    echo "[ERROR] Failed to backup settings for profile '$profile'."
  fi

  if ! backup_keybinds "$profile_path/keybindings.json" "$outdir" "$profile"; then
    echo "[ERROR] Failed to backup keybindings for profile '$profile'."
  fi

  if $TRIM; then
    cleanup_backups "$outdir" "$RETAIN"
  fi
}

## Parse CLI args
while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--backup-path)
      BACKUP_DIR="$2"
      shift 2
      ;;
    -r|--retain)
      RETAIN="$2"
      shift 2
      ;;
    -t|--trim)
      TRIM=true
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [-p PATH] [-r RETAIN] [-t]"
      echo "  -p, --backup-path   Backup directory (default: $HOME/VSCodeBackup)"
      echo "  -r, --retain        Number of backups to retain (default: 3)"
      echo "  -t, --trim          Trim older backups beyond retention count"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

## Check VSCode CLI
if ! command -v code &>/dev/null; then
  echo "Error: VS Code CLI (code) not found. Please install VS Code and ensure 'code' is in PATH."
  exit 1
fi

## Check jq presence
if ! command -v jq &>/dev/null; then
  echo "Error: jq not found. Please install jq."
  exit 1
fi

## Create backup dir if missing
mkdir -p "$BACKUP_DIR"

## Default VSCode User directory
DEFAULT_USER_PATH="$HOME/.config/Code/User"

## Backup default profile
if [[ -d "$DEFAULT_USER_PATH" ]]; then
  backup_profile "default" "$DEFAULT_USER_PATH"
else
  echo "Warning: Default VS Code user directory not found at $DEFAULT_USER_PATH"
fi

## Backup named profiles
PROFILES_ROOT="$DEFAULT_USER_PATH/profiles"
if [[ -d "$PROFILES_ROOT" ]]; then
  shopt -s nullglob
  for profile_dir in "$PROFILES_ROOT"/-* "$PROFILES_ROOT"/*; do
    [[ -d "$profile_dir" ]] || continue

    profile_name=$(basename "$profile_dir")
    friendly_name=""
    profile_json="$profile_dir/profile.json"
    if [[ -f "$profile_json" ]]; then
      friendly_name=$(jq -r '.name' "$profile_json" || echo "")
    fi

    echo "Backing up profile directory: $profile_dir as profile name: $profile_name (friendly name: $friendly_name)"
    backup_profile "$profile_name" "$profile_dir" "$friendly_name"
  done
else
  echo "No profiles directory found, only backed up default profile."
fi
