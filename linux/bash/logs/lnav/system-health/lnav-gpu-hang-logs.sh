#!/usr/bin/env bash
set -euo pipefail

sudo journalctl -k -b -1 | grep -iE "amdgpu|i915|nvidia|drm|gpu hang" | lnav
