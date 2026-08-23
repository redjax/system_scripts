#!/usr/bin/env bash
set -euo pipefail

DEFAULT_CONNECTION="Wired connection 1"

function usage() {
  cat <<EOF
Usage: $0 [-c|--connection-name NAME] -d|--dns IPv4

Options:
  -c, --connection-name NAME   NetworkManager connection name
                               (default: "$DEFAULT_CONNECTION")
  -d, --dns IPv4               DNS server IPv4 address
  -h, --help                   Show this help

Examples:
  $0 --dns 192.168.1.5
  $0 -c "Wired connection 1" -d 192.168.1.5
EOF
}

function error() {
  echo "[ERROR] $*" >&2
  exit 1
}

function info() {
  echo "[INFO] $*"
}

## Basic dependency checks
command -v nmcli >/dev/null 2>&1 ||
  error "nmcli is not installed"

command -v sudo >/dev/null 2>&1 ||
  error "sudo is not installed"

## Parse args
connection="$DEFAULT_CONNECTION"
dns=""

while [[ $# -gt 0 ]]; do
  case "$1" in
  -c | --connection-name)
    [[ $# -ge 2 ]] ||
      error "$1 requires an argument"

    connection="$2"
    shift 2
    ;;

  -d | --dns)
    [[ $# -ge 2 ]] ||
      error "$1 requires an argument"

    dns="$2"
    shift 2
    ;;

  -h | --help)
    usage
    exit 0
    ;;

  --)
    shift
    [[ $# -eq 0 ]] ||
      error "Unexpected arguments after --"
    ;;

  -*)
    error "Unknown option: $1"
    ;;

  *)
    error "Unexpected argument: $1"
    ;;
  esac
done

[[ -n "$connection" ]] ||
  error "Connection name cannot be empty"

[[ -n "${connection//[[:space:]]/}" ]] ||
  error "Connection name cannot contain only whitespace"

[[ -n "$dns" ]] ||
  error "--dns is required"

[[ -n "${dns//[[:space:]]/}" ]] ||
  error "DNS address cannot contain only whitespace"

## Validate DNS address
#  ipv4.dns expects IP addresses, not hostnames.
if [[ ! "$dns" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  error "DNS '$dns' is not a valid IPv4 address"
fi

## Validate each octet numerically.
IFS='.' read -r octet1 octet2 octet3 octet4 <<<"$dns"

for octet in "$octet1" "$octet2" "$octet3" "$octet4"; do
  ## Avoid weird values such as 001foo.
  [[ "$octet" =~ ^[0-9]+$ ]] ||
    error "DNS '$dns' contains an invalid IPv4 octet"

  ((octet <= 255)) ||
    error "DNS '$dns' contains an IPv4 octet greater than 255"
done

## Make sure NetworkManager is running
if ! nmcli general status >/dev/null 2>&1; then
  error "NetworkManager does not appear to be running"
fi

## Find the connection
if ! nmcli connection show id "$connection" >/dev/null 2>&1; then
  error "NetworkManager connection '$connection' does not exist"
fi

## Make sure sudo can authenticate before we start changing anything.
if [[ "$EUID" -ne 0 ]]; then
  echo "[WARNING] Script was not run with root/sudo"
  echo "Testing sudo authentication (runs sudo -v):"

  if ! sudo -v; then
    error "Unable to obtain sudo privileges"
  fi
fi

## Inspect current configuration
old_dns="$(nmcli -g ipv4.dns connection show id "$connection")"
old_ignore_auto_dns="$(nmcli -g ipv4.ignore-auto-dns connection show id "$connection")"

info "Connection: $connection"
info "Current DNS: ${old_dns:-<none>}"
info "New DNS:     $dns"

## Apply configuration
info "Setting DNS configuration"

if ! sudo nmcli connection modify id "$connection" \
  ipv4.dns "$dns" \
  ipv4.ignore-auto-dns yes; then

  error "Failed to modify connection '$connection'"
fi

## Reactivate the connection.
#  If this fails, attempt to restore the previous DNS configuration.

info "Reactivating connection"

if ! sudo nmcli connection up id "$connection"; then
  echo "[ERROR] Failed to reactivate connection '$connection'" >&2
  echo "[INFO] Attempting to restore previous DNS configuration" >&2

  if sudo nmcli connection modify id "$connection" \
    ipv4.dns "$old_dns" \
    ipv4.ignore-auto-dns "$old_ignore_auto_dns"; then

    sudo nmcli connection up id "$connection" >/dev/null 2>&1 || true
    echo "[INFO] Previous DNS configuration restored." >&2
  else
    echo "[ERROR] WARNING: Failed to restore previous DNS configuration!" >&2
  fi

  exit 1
fi

## Verify what NetworkManager actually has configured.
actual_dns="$(nmcli -g ipv4.dns connection show id "$connection")"
actual_ignore_auto_dns="$(nmcli -g ipv4.ignore-auto-dns connection show id "$connection")"

if [[ "$actual_dns" != "$dns" ]]; then
  echo "[ERROR] DNS verification failed." >&2
  echo "[ERROR] Expected: $dns" >&2
  echo "[ERROR] Actual:   $actual_dns" >&2
  exit 1
fi

if [[ "$actual_ignore_auto_dns" != "yes" ]]; then
  echo "[ERROR] ipv4.ignore-auto-dns verification failed." >&2
  echo "[ERROR] Expected: yes" >&2
  echo "[ERROR] Actual:   $actual_ignore_auto_dns" >&2
  exit 1
fi

info "DNS configuration applied successfully."
info "DNS: $actual_dns"
info "Auto DNS: disabled"
