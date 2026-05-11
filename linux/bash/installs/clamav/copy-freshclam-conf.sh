#!/usr/bin/env bash
set -uo pipefail

if ! command -v freshclam &>/dev/null; then
    echo "freshclam is not installed."
    exit 1
fi


THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"


## Common freshclam.conf paths (in priority order)
declare -a CONF_PATHS=(
    "/etc/freshclam.conf"
    "/usr/local/etc/freshclam.conf" 
    "/etc/clamav/freshclam.conf"
)

FRESHCLAM_CONF_PATH=""
FORCE=false

function usage() {
    cat <<EOF
Usage: $0 [-f] [-h]

Options:
  -f, --force  Force overwrite (skips all prompts)
  -h, --help   Show this help

Copies freshclam.conf from script directory to system location.
EOF
}

function handle_copy() {
    sudo cp "$SRC_CONF" "$FRESHCLAM_CONF_PATH"
    echo "Copied: $SRC_CONF → $FRESHCLAM_CONF_PATH"
}

## Find existing config
for path in "${CONF_PATHS[@]}"; do
    if [[ -f "$path" ]]; then
        FRESHCLAM_CONF_PATH="$path"
        echo "Found existing: $FRESHCLAM_CONF_PATH"
        break
    fi
done

## If no config found in common paths, try to detect based on distro info
if [[ -z "$FRESHCLAM_CONF_PATH" ]]; then
    if [[ -r /etc/os-release ]]; then
        . /etc/os-release
        case "$ID" in
            debian|ubuntu|linuxmint|raspbian|pop|mint)
                FRESHCLAM_CONF_PATH="/etc/clamav/freshclam.conf"
                ;;
            rhel|centos|rocky|almalinux|fedora|ol)
                FRESHCLAM_CONF_PATH="/etc/freshclam.conf"
                ;;
            opensuse*|sles)
                FRESHCLAM_CONF_PATH="/etc/clamav/freshclam.conf"
                ;;
            arch|manjaro|endeavouros)
                FRESHCLAM_CONF_PATH="/etc/clamav/freshclam.conf"
                ;;
            *)
                echo "Warning: Unknown distro ID '$ID', defaulting to /etc/clamav/freshclam.conf" >&2
                FRESHCLAM_CONF_PATH="/etc/clamav/freshclam.conf"
                ;;
        esac
        echo "Predicted target: $FRESHCLAM_CONF_PATH (distro: $ID)"
    else
        FRESHCLAM_CONF_PATH="/etc/clamav/freshclam.conf"
        echo "Warning: No /etc/os-release; using default: $FRESHCLAM_CONF_PATH" >&2
    fi
fi

## Parse args
while [[ $# -gt 0 ]]; do
    case "$1" in
        -f|--force) FORCE=true; shift ;;
        -h|--help)  usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
    esac
done

SRC_CONF="$THIS_DIR/freshclam.conf"
if [[ ! -f "$SRC_CONF" ]]; then
    echo "Error: $SRC_CONF not found" >&2
    exit 1
fi

echo "Target: $FRESHCLAM_CONF_PATH"

if [[ "$FORCE" == true ]]; then
    echo "FORCE mode: copying"
    handle_copy
    exit 0
fi

## Backup check
BACKUP_PATH="${FRESHCLAM_CONF_PATH}.orig"
if [[ -f "$FRESHCLAM_CONF_PATH" ]]; then  # ← ADD THIS LINE
    if [[ -f "$BACKUP_PATH" ]]; then
        echo "Warning: Backup already exists: $BACKUP_PATH"
        echo "Skipping backup creation."
    else
        if read -r -p "Create backup of existing config? (y/n): " yn && [[ "$yn" =~ ^[Yy]$ ]]; then
            sudo cp "$FRESHCLAM_CONF_PATH" "$BACKUP_PATH"
            echo "Backup created: $BACKUP_PATH"
        else
            echo "Skipping backup."
        fi
    fi
else
    echo "No existing config to backup at $FRESHCLAM_CONF_PATH"
fi

## Overwrite check
if [[ -f "$FRESHCLAM_CONF_PATH" ]]; then  # ← ADD THIS LINE
    if read -r -p "Overwrite $FRESHCLAM_CONF_PATH? (y/n): " yn && [[ "$yn" =~ ^[Yy]$ ]]; then
        handle_copy
    else
        echo "Aborted."
    fi
else
    echo "No existing config. Copying freshclam.conf to $FRESHCLAM_CONF_PATH"
    handle_copy
fi

