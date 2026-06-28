#!/usr/bin/env bash
set -euo pipefail

sudo journalctl -k -b -1 | grep -i oom | lnav
