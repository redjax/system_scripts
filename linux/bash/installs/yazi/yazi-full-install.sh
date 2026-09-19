#!/usr/bin/env bash
set -euo pipefail

################################################################################
# Orchestrates Yazi installation scripts.
#                                                                              #
# Installs dependencies first, then Yazi itself, then extras (plugins/themes). #
################################################################################

THIS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

declare -a INSTALL_SCRIPTS=(
  "${THIS_DIR}/install-yazi-dependencies.sh"
  "${THIS_DIR}/install-yazi.sh"
  "${THIS_DIR}/install-yazi-extras.sh"
)

echo ""
echo "[ Install Yazi Terminal File Manager ]"
echo " ------------------------------------"
echo

for script in "${INSTALL_SCRIPTS[@]}"; do
  echo "Running install script: ${script}"

  if ! "${script}" 2>&1; then
    echo "[ERROR] Failed running Yazi install script: ${script}" 2>&1
    exit 1
  fi

  echo
done

echo
echo "Finished installing Yazi, its dependencies, and extras (plugins/themes)"

