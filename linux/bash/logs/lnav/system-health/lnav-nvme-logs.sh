#!/usr/bin/env bash
set -euo pipefail

sudo journalctl -k -b -1 | grep -iE "nvme|i/o error|ext4|btrfs|reset" | lnav
