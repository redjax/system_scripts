#!/usr/bin/env bash
set -euo pipefail

journalctl -k -b -1 | grep -i nvidia | lnav
