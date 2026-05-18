#!/usr/bin/env bash
set -euo pipefail

sudo journalctl -b -1 | grep -iE "ext4|btrfs|nvme|I/O error" | lnav
