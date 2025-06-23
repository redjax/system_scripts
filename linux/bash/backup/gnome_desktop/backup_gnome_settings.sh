#!/bin/bash

## Dump Gnome settings to a file with dconf

CWD=$(pwd)
OUTPUT_FILE="gnome_settings.dconf"
TAR_ARCHIVE_FILE="gnome_settings_backup.tar.gz"

function dump_gnome_settings {
  OUTPUT_PATH=$1
  
  if ! command -v dconf >/dev/null 2>&1; then
    echo "[ERROR] dconf is not installed"
    return 1
  fi

  echo "Dumping Gnome settings to: $OUTPUT_PATH"
  dconf dump / > $OUTPUTS_PATH
  if [[ $? -ne 0 ]]; then
    echo "[ERROR] Failed to dump Gnome settings"
    return $?
  fi
}

function create_tar_backup {
  OUTPUT_PATH=$1
  GNOME_SETTINGS_DUMP_FILE=$2

  if ! command -v tar >/dev/null 2>&1; then
    echo "[ERROR] tar is not installed"
    return 1
  fi

  echo "Creating tar backup at path: $OUTPUT_PATH"
  tar -xzvf $OUTPUT_PATH $GNOME_SETTINGS_DUMP_FILE ~/.config ~/.local/share/gnome-shell/extensions
  if [[ $? -ne 0 ]]; then
    echo "[ERROR] Failed to create tar archive of Gnome settings."
    return $?
  fi
}

function restore_tar_backup {
  ARCHIVE_PATH=$1
  GNOME_SETTINGS_DUMP_FILE=$2

  if [[ ! -f $ARCHIVE_PATH ]]; then
    echo "[ERROR] Could not find archive at path: $ARCHIVE_PATH"
    return 1
  fi

  if [[ ! -f $GNOME_SETTINGS_DUMP_FILE ]]; then
    echo "[ERROR] Could not find Gnome settings dump file at path: $GNOME_SETTINGS_DUMP_FILE"
    return 1
  fi

  dconf load / < $GNOME_SETTINGS_DUMP_FILE
  if [[ $? -ne 0 ]]; then
    echo "[ERROR] Failed to restore Gnome settings from backup."
    return $?
  fi
}
