#!/usr/bin/env bash
set -euo pipefail

if ! command -v docker &>/dev/null; then
  echo "Docker is not installed." >&2
  exit 1
fi

_BUILD_CODEQL_THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_BUILD_CODEQL_REPO_ROOT="$(realpath -m "${_BUILD_CODEQL_THIS_DIR}/../..")"
CONTAINERS_DIR="${_BUILD_CODEQL_REPO_ROOT}/.containers"
DOCKERFILE="codeql.Dockerfile"
ALPINE_TAG=3.22.4
TAG="${CODEQL_CONTAINER_TAG:-local}"
CWD="$(pwd)"
trap 'cd "${CWD}"' EXIT

echo "Building codeQL Docker container"

cd "${_BUILD_CODEQL_REPO_ROOT}"

if ! docker build -t system_scripts-codeql:"${TAG}" -f "${CONTAINERS_DIR}/${DOCKERFILE}" --build-arg ALPINE_IMG_VER="${ALPINE_TAG}" .; then
  echo "[ERROR] Failed building codeQL Docker container" >&2
  exit 1
fi
