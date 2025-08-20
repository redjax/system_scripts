#!/usr/bin/env bash

######################################
# Backup VS Code settings, keybinds, #
# and extensions for all profiles.   #
######################################

set -euo pipefail

## Set values
BACKUP_DIR="$HOME/VSCodeBackup"
RETAIN=3
TRIM=false

## Return a timestamp
timestamp() {
  date +"%Y%m%d_%H%M%S"
}

## Cleanup function for a profile directory
cleanup_backups() {
  local dir="$1"
  local retain="$2"
  
  echo
  echo "=== Cleanup ==="
  echo

  echo "+ Cleaning up backups in $dir (retain $retain)..."
  echo

  for pattern in "*_settings.json" "*_keybinds.json" "*_extensions.txt"; do
    files=( $(ls -t "$dir"/$pattern 2>/dev/null || true) )
    
    if (( ${#files[@]} > retain )); then
      to_delete=( "${files[@]:$retain}" )
      
      for f in "${to_delete[@]}"; do
        echo "  Removing: $f"
        rm -f "$f"
      done

    fi

  done
}

## Backup VSCode extensions
backup_extensions() {
  local outdir="$1"
  local profile="$2"
  local ts
  ts=$(timestamp)
  local outfile="$outdir/${ts}_extensions.txt"

  echo "+ Backing up extensions for profile '$profile' -> $outfile"
  
  if [[ "$profile" == "default" ]]; then
    code --list-extensions > "$outfile"
  else
    code --list-extensions --profile="$profile" > "$outfile"
  fi
}

## Backup VSCode settings
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

## Backup VSCode keybindings
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

## Backup full profile (call other backup functions)
backup_profile() {
  local profile="$1"
  local profile_path="$2"
  local outdir="$BACKUP_DIR/$profile"

  mkdir -p "$outdir"

  echo
  echo "=== Backing up profile: $profile ==="
  echo

  backup_extensions "$outdir" "$profile"
  if [[ $? -ne 0 ]]; then
    echo "[ERROR] Failed to backup extensions for profile '$profile'."
  fi

  backup_settings "$profile_path/settings.json" "$outdir" "$profile"
  if [[ $? -ne 0 ]]; then
    echo "[ERROR] Failed to backup settings for profile '$profile'."
  fi

  backup_keybinds "$profile_path/keybindings.json" "$outdir" "$profile"
  if [[ $? -ne 0 ]]; then
    echo "[ERROR] Failed to backup keybindings for profile '$profile'."
  fi

  if $TRIM; then
    cleanup_backups "$outdir" "$RETAIN"
  fi
}

## Parse CLI arguments
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

## Test VSCode installed
if ! command -v code &>/dev/null; then
  echo "Error: VS Code (code CLI) not found in PATH."
  exit 1
fi

## Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

## Default VSCode path
DEFAULT_USER_PATH="$HOME/.config/Code/User"

## Backup default profile
if [[ -d "$DEFAULT_USER_PATH" ]]; then
  backup_profile "default" "$DEFAULT_USER_PATH"
else
  echo "Warning: VS Code user directory not found at $DEFAULT_USER_PATH"
fi

## Backup named profiles
PROFILES_ROOT="$DEFAULT_USER_PATH/profiles"
if [[ -d "$PROFILES_ROOT" ]]; then
  for dir in "$PROFILES_ROOT"/*/; do
    profile_name=$(basename "$dir")
    backup_profile "$profile_name" "$dir"
  done
else
  echo "No VS Code profiles directory found, only backed up default profile."
fi
