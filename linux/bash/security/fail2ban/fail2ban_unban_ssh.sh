#!/bin/bash

## Unban an app from the SSHD fail2ban jail

if ! command -v fail2ban-client &>/dev/null; then
  echo "Fail2Ban client is not installed."
  exit 1
fi

IP_ADDR=""

function print_help() {
  echo ""
  echo "Description: Unban an IP address that was blocked by Fail2Ban."
  echo ""
  echo "Usage:"
  echo "${0} [--ip | --ip-address] <xxx.xxx.xxx.xxx>"
  echo ""
  echo "--ip | --ip-address  The IP address to unban if it exists in the Fail2Ban blocklist for SSHD jail"
  echo "  -h | --help          Print help menu"
  echo ""
}

while [[ $# -gt 0 ]]; do
  case $1 in
  --ip | --ip-address)
    if [[ -z "$2" ]]; then
      echo "[ERROR] --ip-address provided, but no IP address given."
      print_help
      exit 1
    fi

    IP_ADDR="$2"
    shift
    ;;
  -h | --help)
    print_help
    exit 0
    ;;
  esac
done

if [[ "${IP_ADDR}" == "" ]]; then
  echo "[ERROR] Missing IP address to unban."
  exit 1
fi

echo "Unbanning IP $IP_ADDR from Fail2Ban SSH jail"

sudo fail2ban-client set sshd unbanip $IP_ADDR
if [[ $? -ne 0 ]]; then
  echo "[ERROR] Failed to unban IP from SSH jail."
  exit $?
else
  echo "IP ${IP_ADDR} unbanned from SSH jail."
  exit 0
fi
