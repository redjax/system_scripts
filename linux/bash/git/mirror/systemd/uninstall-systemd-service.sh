#!/usr/bin/env bash
set -euo pipefail

SYSTEMD_USER_DIR="${HOME}/.config/systemd/user"

echo "[+] Disabling timer"

systemctl --user disable --now git-mirror.timer 2>/dev/null || true

echo "[+] Removing unit files"

rm -f \
  "${SYSTEMD_USER_DIR}/git-mirror.service" \
  "${SYSTEMD_USER_DIR}/git-mirror.timer"

echo "[+] Reloading systemd user daemon"

systemctl --user daemon-reload

echo ""
echo "[+] Uninstalled successfully"
