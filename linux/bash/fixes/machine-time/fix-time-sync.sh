#!/usr/bin/env bash
set -euo pipefail

echo "[ Time Sync Repair ]"

## Detect root
if [[ $EUID -ne 0 ]]; then
  echo "Run as root (or sudo)." >&2
  exit 1
fi

function have_cmd() { command -v "$1" >/dev/null 2>&1; }

function start_service() {
  ## systemd path
  if have_cmd systemctl; then
    systemctl enable --now "$1" 2>/dev/null || true
  fi
}

function install_pkg() {
  PKG="$1"

  if have_cmd apt-get; then
    apt-get update
    apt-get install -y "$PKG"

  elif have_cmd dnf; then
    dnf install -y "$PKG"

  elif have_cmd yum; then
    yum install -y "$PKG"

  elif have_cmd zypper; then
    zypper install -y "$PKG"

  elif have_cmd pacman; then
    pacman -Sy --noconfirm "$PKG"

  elif have_cmd apk; then
    apk add --no-cache "$PKG"

  else
    echo "[ERROR] No supported package manager found." >&2
    exit 1
  fi
}

echo "Detecting time sync capability"

## systemd-timesyncd (preferred on systemd systems)
if have_cmd timedatectl && systemctl is-system-running >/dev/null 2>&1; then
  echo "Using systemd timedatectl"

  timedatectl set-ntp true || true
  timedatectl status

  echo "Done"
  exit 0
fi

## chrony (best cross-distro option)
if have_cmd chronyc || systemctl list-unit-files 2>/dev/null | grep -q chrony; then
  echo "Using chrony"

  install_pkg chrony

  start_service chronyd || start_service chrony || true

  if have_cmd chronyc; then
    chronyc makestep || true
    chronyc tracking || true
  fi

  echo "Done"
  exit 0
fi

## ntpd fallback
if have_cmd ntpd || systemctl list-unit-files 2>/dev/null | grep -q ntp; then
  echo "Using ntpd"
  install_pkg ntp

  start_service ntp || start_service ntpd || true

  if have_cmd ntpd; then
    ntpq -p || true
  fi

  echo "Done"
  exit 0
fi

## Alpine minimal fallback (openntpd is common)
echo "Installing openntpd fallback"
install_pkg openntpd
start_service openntpd || true

echo "Done

echo "Current time:"
date

