#!/bin/bash

##
# Script to detect OS and install rsync accordingly.
##

set -euo pipefail

if command -v resticprofile; then
  echo "resticprofile is already installed."
  exit 0
fi

if ! command -v curl &>/dev/null; then
  echo "curl is not installed. Please install curl & try again."
  exit 1
fi

echo "Downloading & executing resticprofile install script."
sudo sh -c "$(curl -fsLS https://raw.githubusercontent.com/creativeprojects/resticprofile/master/install.sh)" -- -b /usr/local/bin
if [[ $? -ne 0 ]]; then
  echo "Failed installing resticprofile."
  exit $?
else
  echo "resticprofile installed successfully."
  exit 0
fi
