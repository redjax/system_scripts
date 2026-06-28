#!/usr/bin/env bash
set -euo pipefail

sudo journalctl -k -b -1 | tail -300 | lnav
