#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="$HOME/backups/thunderbird"
THUNDERBIRD_DIR="$HOME/.thunderbird"
FLATPAK_DIR="$HOME/.var/app/org.mozilla.Thunderbird"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
ARCHIVE_NAME="thunderbird_backup_$TIMESTAMP.tar.gz"

function usage() {
  echo ""
  echo "Usage: ${0} [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  -h, --help                           Print this help menu"
  echo "  -o, --output-dir <path/to/backups/>  Directory where backup archives will be saved"
  echo ""
}

while [[ $# -gt 0 ]]; do
  case $1 in
  -o | --output-dir)
    if [[ -z "$2" ]]; then
      echo "[ERROR] --output-dir provided, but no directory path given" >&2
      usage
      exit 1
    fi

    BACKUP_DIR="$2"
    shift 2
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    echo "[ERROR] Invalid arg: $1" >&2
    usage
    exit 1
    ;;
  esac
done

mkdir -p "$BACKUP_DIR"

DIRS_TO_BACKUP=("$THUNDERBIRD_DIR")
if [ -d "$FLATPAK_DIR" ]; then
  DIRS_TO_BACKUP+=("$FLATPAK_DIR")
fi

echo "Creating backup archive: $BACKUP_DIR/$ARCHIVE_NAME"
tar -czpf "$BACKUP_DIR/$ARCHIVE_NAME" "${DIRS_TO_BACKUP[@]}"

echo "Backup completed successfully!"
echo "Archive saved at: $BACKUP_DIR/$ARCHIVE_NAME"
