#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  set-udev-permissions.sh --allow --device /dev/hidraw#
  set-udev-permissions.sh --deny  --device /dev/hidraw#
  set-udev-permissions.sh --help

Notes:
  - --allow and --deny are mutually exclusive.
  - --device is required for allow/deny.
  - If no action is provided, the script prompts you to use --allow or --deny.
  - If no device is provided, the script explains how to find the hidraw node in Chrome device logs.
EOF
}

allow=false
deny=false
device=""

while [[ $# -gt 0 ]]; do
  case "$1" in
  --allow)
    if $deny; then
      echo "Error: --allow and --deny cannot be used together." >&2
      exit 2
    fi
    allow=true
    shift
    ;;
  --deny)
    if $allow; then
      echo "Error: --allow and --deny cannot be used together." >&2
      exit 2
    fi
    deny=true
    shift
    ;;
  --device)
    device="${2:-}"
    [[ -n "$device" ]] || {
      echo "Error: --device requires a value." >&2
      exit 2
    }
    shift 2
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    echo "Error: unknown argument: $1" >&2
    usage
    exit 2
    ;;
  esac
done

if ! $allow && ! $deny; then
  echo "Error: you must pass either --allow or --deny." >&2
  usage
  exit 2
fi

if [[ -z "$device" ]]; then
  cat <<'EOF'
No device was provided. You must pass /dev/hidraw{num}.

Follow the steps below to find which /dev/hidraw device you should use:

1. Open https://launcher.keychron.com/
2. Try to connect your keyboard.
3. Open chrome://device-log/
4. Look for a line like:
   Failed to open '/dev/hidraw3': FILE_ERROR_ACCESS_DENIED
5. Re-run this script with:
   --device /dev/hidraw3
EOF
  exit 1
fi

if [[ ! -e "$device" ]]; then
  echo "Error: device does not exist: $device" >&2
  exit 1
fi

if $allow; then
  sudo chmod a+rw "$device"
  echo "Allowed access on $device"
else
  sudo chmod 600 "$device"
  echo "Denied access on $device"
fi

