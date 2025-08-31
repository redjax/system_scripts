#!/bin/bash

## Default values
BACKUP_PATH="$HOME/backup/cron"
CRON_USERS=()
BACKUP_ROOT=0
BACKUP_ALL=0

## Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    -u|--user)
      if [[ -z $2 ]]; then
        echo "[ERROR] --user flag provided but no username given."
        exit 1
      fi
      CRON_USERS+=("$2")
      shift 2
      ;;
    -p|--backup-path)
      BACKUP_PATH="$2"
      shift 2
      ;;
    --root)
      BACKUP_ROOT=1
      shift
      ;;
    --all)
      BACKUP_ALL=1
      shift
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Set CRON_USERS default to current user if no --user, --all, or --root flag
if [[ ${#CRON_USERS[@]} -eq 0 && $BACKUP_ALL -eq 0 && $BACKUP_ROOT -eq 0 ]]; then
    CRON_USERS+=("$(whoami)")
fi

TODAY=$(date '+%Y-%m-%d_%H-%M-%S')

mkdir -p "${BACKUP_PATH}"

require_root() {
  local test_user="$1"
  local current_user
  current_user="$(whoami)"

  if [[ "$test_user" != "$current_user" && "$EUID" -ne 0 ]]; then
    echo "[ERROR] You need root to backup crontab for user '$test_user'"
    
    return 1
  else
    return 0
  fi
}

backup_crontab() {
    local user="$1"
    
    local current_user
    current_user="$(whoami)"
    local dest="$BACKUP_PATH/${TODAY}_${user}_crontab.txt"

    if ! id "$user" &>/dev/null; then
        echo "[WARNING] User '$user' does not exist. Skipping."
        
        return 1
    fi

    if [[ "$user" == "$current_user" && "$EUID" -ne 0 ]]; then
        # Backup own crontab, no -u
        if ! crontab -l &>/dev/null; then
            echo "[WARNING] User '$user' has no crontab. Skipping."
            
            return 1
        fi
        
        crontab -l > "$dest"
    else
        # Backing up someone else, must be root
        require_root "$user" || return 1
        
        if ! crontab -l -u "$user" &>/dev/null; then
            echo "[WARNING] User '$user' has no crontab. Skipping."
            
            return 1
        fi
        
        crontab -l -u "$user" > "$dest"
    fi
    
    echo "Backed up user's crontab: ${user} > ${dest}"
    return 0
}

if [[ $BACKUP_ROOT -eq 1 ]]; then
    backup_crontab root
elif [[ $BACKUP_ALL -eq 1 ]]; then
    all_users=$(awk -F: '($7 ~ /(sh|bash|zsh)$/){print $1}' /etc/passwd)
    
    for u in $all_users; do
      if ! backup_crontab "$u"; then
        echo "[WARNING] Failed crontab backup for user '$u'"
      fi
    done
    
    if ! backup_crontab root; then
      echo "[WARNING] Failed crontab backup for user 'root'"
    fi
else
    for u in "${CRON_USERS[@]}"; do
        if ! backup_crontab "$u"; then
          echo "[WARNING] Failed crontab backup for user '$u'"
        fi
    done
fi

