#!/usr/bin/env bash
set -euo pipefail

if ! command -v docker &>/dev/null; then
  echo "Docker is not installed." >&2
  exit 1
fi

_RUN_CODEQL_THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_RUN_CODEQL_REPO_ROOT="$(realpath -m "${_RUN_CODEQL_THIS_DIR}/../..")"
CWD="$(pwd)"
trap 'cd "${CWD}"' EXIT

echo "Running codeQL Docker container"

cd "${_RUN_CODEQL_REPO_ROOT}"

echo "[+] Lint Bash"

if ! docker run --rm --user "$(id -u):$(id -g)" -v "$(pwd):/repo" system_scripts-codeql:local "bash ./repo_scripts/codeql/lint-bash.sh"; then
  echo "[ERROR] Found problems while linting Bash files" >&2
fi

echo "[+] Format Bash"

if ! docker run --rm --user "$(id -u):$(id -g)" -v "$(pwd):/repo" system_scripts-codeql:local "bash ./repo_scripts/codeql/format-bash.sh"; then
  echo "[ERROR] Failed formatting Bash files" >&2
fi

echo "[+] Lint Python"

if ! docker run --rm --user "$(id -u):$(id -g)" -v "$(pwd):/repo" system_scripts-codeql:local "bash ./repo_scripts/codeql/lint-python.sh"; then
  echo "[ERROR] Found problems while linting Python files" >&2
fi

echo "[+] Format Python"

if ! docker run --rm --user "$(id -u):$(id -g)" -v "$(pwd):/repo" system_scripts-codeql:local "bash ./repo_scripts/codeql/format-python.sh"; then
  echo "[ERROR] Failed formatting Python files" >&2
fi

echo
echo "Done"
