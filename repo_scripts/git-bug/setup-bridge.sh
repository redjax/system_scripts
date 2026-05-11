#!/usr/bin/env bash
set -euo pipefail

##
# Run this script when cloning the repo on a new machine,
# or to set up a new branch.
#
# The script uses git-bug's guided bridge setup.
##

if ! command -v git bug >&/dev/null; then
  echo "[ERROR] git-bug is not installed" >&2
  exit 1
fi

git bug bridge new

