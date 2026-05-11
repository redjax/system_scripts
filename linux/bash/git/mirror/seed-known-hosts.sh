#!/usr/bin/env bash
set -euo pipefail

###################################################################
# Seeds the known_hosts file to avoid hanging on the first clone. #
#                                                                 #
# Run this script before any others.                              #
###################################################################

hosts=(github.com gitlab.com codeberg.org)

echo "Seeding ~/.ssh/known_hosts with ${hosts[*]}"

mkdir -p ~/.ssh
touch ~/.ssh/known_hosts

if ! ssh-keyscan "${hosts[@]}" >> ~/.ssh/known_hosts 2>/dev/null; then
  echo "[ERROR] Failed seeding known hosts file." >&2
  exit 1
fi
