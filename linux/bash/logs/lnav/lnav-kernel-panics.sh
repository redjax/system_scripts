#!/usr/bin/env bash
set -euo pipefail

if ! command -v lnav >/dev/null 2>&1; then
    echo "[ERROR] lnav is not installed." >&2
    exit 1
fi

echo "Starting lnav, looking for kernel panics..."
echo "[WARNING] Reading kernel logs requires sudo permissions."

PATTERN='panic|kernel panic|oops|BUG:|WARNING:|Call Trace:|RIP:|general protection fault|segfault|soft lockup|hard LOCKUP|watchdog|hung task|rcu.*stall|mce|Machine Check|I/O error|nvme|pcie|fatal'

tmpfile=$(mktemp)
trap 'rm -f "$tmpfile"' EXIT

echo "Starting LNAV, showing kernel panic logs"

sudo journalctl -k -b -1 |
    grep -Ei "$PATTERN" >"$tmpfile" || true

if [[ ! -s "$tmpfile" ]]; then
    echo "[INFO] No matching kernel panic logs found."
    exit 0
fi

exec lnav "$tmpfile"