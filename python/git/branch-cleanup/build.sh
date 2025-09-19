#!/bin/bash

set -uo pipefail

if ! command -v docker &> /dev/null
then
    echo "docker could not be found"
    exit
fi

echo "Building branch-cleanup image"
docker build -t branch-cleanup .
if [[ $? -ne 0 ]]; then
    echo "[ERROR] Failed building branch-cleanup image"
    exit 1
else
    echo "Successfully built branch-cleanup image"
    exit 0
fi
