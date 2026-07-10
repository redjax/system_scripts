#!/usr/bin/env bash
set -euo pipefail

## Flyline: https://github.com/HalFrgrd/flyline

if ! command -v curl >&/dev/null; then
  echo "[ERROR] curl is not installed" >&2
  exit 1
fi

if [[ -f "${HOME}/.local/lib/libflyline.so" ]]; then
  echo "Flyline is already installed."
  echo
  read -r -n 1 -p "Re-run install script to update? (y/n)" update_choice
  echo

  while true; do
    case $update_choice in
      [Yy])
        echo "Continuing"
        break
        ;;
      [Nn])
        echo "Exiting"
        exit 0
        ;;
      *)
        echo "[ERROR] Invalid choice: $update_choice, must be either 'y' or 'n'." >&2
        continue
        ;;
    esac
  done
fi

echo "Installing Flyline"
echo

curl -sSfL https://github.com/HalFrgrd/flyline/releases/latest/download/install.sh | sh

LAST_EXIT=$?

if [[ ! $LAST_EXIT == 0 ]]; then
  echo
  echo "[ERROR] Flyline install failed" >&2
  exit 1
else
  echo
  echo "Flyline installed. Reload your shell with: exec \$SHELL (or log out and back in/close and re-open your terminal)."
  echo "Run 'flyline run-tutorial' to start an interactive tour of Flyline's features."
  exit 0
fi
