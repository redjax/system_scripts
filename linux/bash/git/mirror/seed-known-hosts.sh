#!/usr/bin/env bash
set -euo pipefail

###################################################################
# Seeds the known_hosts file to avoid hanging on the first clone. #
#                                                                 #
# Run this script before any others.                              #
###################################################################

hosts=(github.com gitlab.com codeberg.org)

mkdir -p ~/.ssh
touch ~/.ssh/known_hosts

for host in "${hosts[@]}"; do
  if ! ssh-keygen -F "$host" >/dev/null; then
    echo "Adding $host to known_hosts"
    ssh-keyscan "$host" >> ~/.ssh/known_hosts 2>/dev/null
  else
    echo "$host already exists in known_hosts"
  fi
done
