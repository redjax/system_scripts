#!/usr/bin/env bash
set -uo pipefail

LOG_FILE=""

function usage() {
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -l, --log-file <path>  Path to ClamAV log file (default: /var/log/clamav/system-scan.log)"
    echo "  -h, --help             Show this help menu"
    echo ""
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -l|--log-file)
            if [[ -z "$2" ]]; then
                echo "[ERROR] --log-file provided, but no log file path given."
                exit 1
            fi

            LOG_FILE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

function detect_os() {
    if command -v apt-get &>/dev/null; then
        echo "debian"
    elif command -v dnf &>/dev/null; then
        echo "fedora"
    elif command -v yum &>/dev/null; then
        echo "rhel"
    elif command -v pacman &>/dev/null; then
        echo "arch"
    else
        echo "unknown"
    fi
}

function get_clam_log() {
    case "$OS" in
        debian|arch)
            if [[ -f /var/log/clamav/clamd.log ]]; then
                echo "/var/log/clamav/clamd.log"
            elif [[ -f /var/log/clamd.log ]]; then
                echo "/var/log/clamd.log"
            else
                echo "/var/log/clamav/clamd.log"
            fi
            ;;
        fedora)
            # Fedora clamd@scan service logs to journal, not file
            if systemctl is-active --quiet clamd@scan; then
                echo "journal:clamd@scan"
            elif [[ -f /var/log/clamd.scan ]]; then
                echo "/var/log/clamd.scan"
            else
                echo "/var/log/clamav/clamd.log"
            fi
            ;;
        rhel)
            if [[ -f /var/log/clamd.scan ]]; then
                echo "/var/log/clamd.scan"
            else
                echo "/var/log/clamav/clamd.log"
            fi
            ;;
        *)
            echo "/var/log/clamav/clamd.log"
            ;;
    esac
}

OS=$(detect_os)

if [[ -z "$LOG_FILE" ]]; then
    LOG_FILE=$(get_clam_log)
else
  if [[ ! -f "$LOG_FILE" ]]; then
      echo "[ERROR] Log file $LOG_FILE not found."
      exit 1
  fi
fi

if [[ "$LOG_FILE" =~ ^journal: ]]; then
    SERVICE_NAME="${LOG_FILE#journal:}"
    echo "Tailing journal logs for $SERVICE_NAME (Press Ctrl+C to exit)"
    journalctl -u "$SERVICE_NAME" -f
else
    if [[ ! -f "$LOG_FILE" ]]; then
        echo "Log file $LOG_FILE not found."
        exit 1
    fi
    echo "Tailing log file $LOG_FILE (Press Ctrl+C to exit)"
    tail -f "$LOG_FILE"
fi
