#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "${DIR}")"

SYSTEMD_USER_DIR="${HOME}/.config/systemd/user"

mkdir -p "${SYSTEMD_USER_DIR}"

SERVICE_FILE="${SYSTEMD_USER_DIR}/git-mirror.service"
TIMER_FILE="${SYSTEMD_USER_DIR}/git-mirror.timer"

echo "[+] Installing systemd user units"

cat > "${SERVICE_FILE}" << EOF
[Unit]
Description=Git Mirror Backup

[Service]
Type=oneshot
WorkingDirectory=${REPO_ROOT}
ExecStart=${REPO_ROOT}/run-mirror-script.sh
EOF

cp "${DIR}/git-mirror.timer" "${TIMER_FILE}"

echo "[+] Reloading systemd user daemon"

systemctl --user daemon-reload

echo "[+] Enabling timer"

systemctl --user enable --now git-mirror.timer

echo ""
echo "[+] Installed successfully"
echo ""
echo "Repo root:"
echo "  ${REPO_ROOT}"
echo ""
echo "Timer status:"
echo "  systemctl --user status git-mirror.timer"
echo ""
echo "Logs:"
echo "  journalctl --user -u git-mirror.service -f"
