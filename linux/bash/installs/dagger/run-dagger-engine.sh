#!/usr/bin/env bash

set -uo pipefail

DAGGER_VERSION="v0.19.2"

while [[ $# -gt 0 ]]; do
  case $1 in
    -v|--dagger-version)
      if [[ -z $2 ]]; then
        echo "[ERROR] --dagger-version provided, but no version given."
	exit 1
      fi

      DAGGER_VERSION="$2"
      shift 2
      ;;
    *)
      echo "[ERROR] Invalid argument: $1"
      exit 1
      ;;
  esac
done

CONTAINER_NAME="dagger-engine-$DAGGER_VERSION"

if ! command -v docker &>/dev/null; then
  echo "[ERROR] Docker is not installed."
  exit 1
fi

# Check if dagger engine container is already running
if docker ps --filter "name=^/${CONTAINER_NAME}$" --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  echo "Dagger engine container '${CONTAINER_NAME}' is already running."
  exit 0
fi

echo ""
echo "Starting Dagger engine container: ${CONTAINER_NAME} (version ${DAGGER_VERSION})"
echo ""

docker run -d --name "${CONTAINER_NAME}" \
  --privileged \
  --network host \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /run/dagger:/run/dagger \
  "registry.dagger.io/engine:${DAGGER_VERSION}" --debug

if [[ $? -ne 0 ]]; then
  echo "[ERROR] Failed to run the Dagger engine container."
  exit 1
fi

echo "Dagger engine container started successfully."

