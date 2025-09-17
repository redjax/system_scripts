#!/bin/bash

if ! command -v dnf &> /dev/null; then
    echo "dnf is not installed."
    exit 1
fi

echo "Cleaning DNF cache"

sudo dnf clean all
sudo dnf makecache
