#!/usr/bin/env bash
set -euo pipefail

sudo journalctl -k -b -1 | grep -iE "mce|machine check|hardware error|thermal" | lnav
