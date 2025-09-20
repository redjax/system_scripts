#!/usr/bin/env bash
set -euo pipefail

SERVICE_NAME="backrest"
SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}.service"
BINARY_PATH="/usr/local/bin/backrest"

if ! command -v backrest &>/dev/null; then
    echo "Backrest is not installed."
    exit 1
fi

echo "Stopping and disabling systemd service $SERVICE_NAME..."
if systemctl is-active --quiet "$SERVICE_NAME"; then
    sudo systemctl stop "$SERVICE_NAME"
fi

if systemctl is-enabled --quiet "$SERVICE_NAME"; then
    sudo systemctl disable "$SERVICE_NAME"
fi

echo "Removing systemd service file $SERVICE_PATH, if it exists..."
if [ -f "$SERVICE_PATH" ]; then
    sudo rm -f "$SERVICE_PATH"
fi

echo "Reloading systemd daemon..."
sudo systemctl daemon-reload

echo "Removing Backrest binary at $BINARY_PATH, if it exists..."
if [ -f "$BINARY_PATH" ]; then
    sudo rm -f "$BINARY_PATH"
fi

echo "Backrest uninstalled successfully."
