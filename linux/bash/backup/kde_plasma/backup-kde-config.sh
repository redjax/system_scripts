#!/bin/bash

##
# Schedule this script as a cron job (crontab -e), i.e.:
#   0 */6 * * * /home/$USER/backup-kde-config.sh --backup --archive-file /opt/backup/kde_plasma/kde-config-backup.tar.gz
#
# Add this to the end of the crontab line to output results to a log file:
#   >> /path/to/kde_backup.log 2>&1
# The path for this log file must already exist, and the user must be able to write to it.
# You can set up logrotate to automatically rotate the log file. Create a logrotate file at /etc/logrotate.d/kde_backup:
#   /var/log/backup/kde_backup.log {
#       size 10M
#       rotate 5
#       missingok
#       notifempty
#       compress
#       delaycompress
#       copytruncate
#       daily
#       maxage 15
#       dateext
#       ifempty
#       create 0640 1000 1000
#       sharedscripts
#       postrotate
#           ## You can add any post-rotate commands here if needed
#           :
#       endscript
#   }
##

set -e

# Default values
BACKUP_PATH="$HOME/kde-config-backup.tar.gz"
MODE=""
SHOW_HELP=0

KDE_CONFIG_ITEMS=(
  "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
  "$HOME/.config/plasmarc"
  "$HOME/.config/plasmashellrc"
  "$HOME/.config/plasma-localerc"
  "$HOME/.config/kdeglobals"
  "$HOME/.config/kwinrc"
  "$HOME/.config/kwinrulesrc"
  "$HOME/.config/ksmserverrc"
  "$HOME/.config/kscreenlockerrc"
  "$HOME/.config/kactivitymanagerdrc"
  "$HOME/.config/kactivitymanagerd-statsrc"
  "$HOME/.config/kded5rc"
  "$HOME/.config/kconf_updaterc"
  "$HOME/.config/khotkeysrc"
  "$HOME/.config/kglobalshortcutsrc"
  "$HOME/.config/kcminputrc"
  "$HOME/.config/kaccessrc"
  "$HOME/.config/dolphinrc"
  "$HOME/.config/konquerorrc"
  "$HOME/.config/korgacrc"
  "$HOME/.config/krunnerrc"
  "$HOME/.config/kmixrc"
  "$HOME/.config/ksplashrc"
  "$HOME/.config/ktimezonedrc"
  "$HOME/.config/powerdevilrc"
  "$HOME/.config/powermanagementprofilesrc"
  "$HOME/.config/discoverrc"
  "$HOME/.config/spectaclerc"
  "$HOME/.config/okularpartrc"
  "$HOME/.config/kdialogrc"
  "$HOME/.config/kiorc"
  "$HOME/.config/kfontinstuirc"
  "$HOME/.config/kdeconnect"
  "$HOME/.config/KDE"
)

usage() {
  cat <<EOF
Usage: $0 [--backup | --restore] [--archive-file PATH] [--help]

Options:
  --backup           Create a KDE config backup archive.
  --restore          Restore KDE config from an archive.
  --archive-file PATH Specify the path to the backup archive (default: $HOME/kde-config-backup.tar.gz).
  --help             Show this help message and exit.

Examples:
  $0 --backup
  $0 --backup --archive-file /path/to/my-kde-backup.tar.gz
  $0 --restore --archive-file /path/to/my-kde-backup.tar.gz
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --backup)
      MODE="backup"
      shift
      ;;
    --restore)
      MODE="restore"
      shift
      ;;
    --archive-file)
      BACKUP_PATH="$2"
      shift 2
      ;;
    --help)
      SHOW_HELP=1
      shift
      ;;
    *)
      echo "[ERROR] Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

if [[ $SHOW_HELP -eq 1 ]]; then
  usage
  exit 0
fi

if [[ -z "$MODE" ]]; then
  echo "[ERROR] You must specify either --backup or --restore."
  usage
  exit 1
fi

if [[ "$MODE" == "backup" ]]; then
  echo "Creating KDE backup archive at: $BACKUP_PATH"
  TMPDIR=$(mktemp -d)
  mkdir -p "$TMPDIR/.config"
  for ITEM in "${KDE_CONFIG_ITEMS[@]}"; do
    if [[ -e "$ITEM" ]]; then
      REL_PATH=".config/$(basename "$ITEM")"
      echo "Adding $ITEM"
      cp -a "$ITEM" "$TMPDIR/.config/"
    else
      echo "[INFO] $ITEM does not exist, skipping."
    fi
  done
  # Remove existing archive if it exists
  if [[ -f "$BACKUP_PATH" ]]; then
    echo "Removing existing archive: $BACKUP_PATH"
    rm -f "$BACKUP_PATH"
  fi
  tar -czf "$BACKUP_PATH" -C "$TMPDIR" .config
  rm -rf "$TMPDIR"
  echo "Backup complete: $BACKUP_PATH"

elif [[ "$MODE" == "restore" ]]; then
  if [[ ! -f "$BACKUP_PATH" ]]; then
    echo "[ERROR] Backup archive not found: $BACKUP_PATH"
    exit 1
  fi
  echo "Restoring KDE config from $BACKUP_PATH"
  tar -xzf "$BACKUP_PATH" -C "$HOME"
  echo "Restore complete!"
fi
