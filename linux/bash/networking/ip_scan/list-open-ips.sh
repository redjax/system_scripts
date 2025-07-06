#!/bin/bash

set -e

RANGE="${1:-192.168.1.1-100}"
if ! command -v nmap >/dev/null 2>&1; then
  echo "nmap is not installed."
  exit 1
fi

echo "Scanning range: $RANGE ..."
sudo nmap -v -sn -n $RANGE -oG - | awk '/Status: Down/ {print $2}'
if [[ $? -ne 0 ]]; then
  echo "Failed to scan range: $RANGE"
  exit $?
fi

echo ""
echo "Scanned range: $RANGE"
