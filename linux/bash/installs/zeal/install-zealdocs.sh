#!/bin/bash

if [ -f /etc/os-release ]; then
  . /etc/os-release
else
  echo "Cannot detect Linux distribution! /etc/os-release missing."
  exit 1
fi

echo "Detected distribution: $NAME"

install_zeal_debian() {
  echo "Updating package list..."
  sudo apt-get update
  echo "Installing Zeal..."
  sudo apt-get install -y zeal
}

install_zeal_rhel() {
  echo "Installing Zeal..."
  sudo dnf install -y zeal
}

install_zeal_arch() {
  echo "Updating packages and installing Zeal..."
  sudo pacman -Syu --noconfirm zeal
}

install_zeal_opensuse() {
  echo "Refreshing repos and installing Zeal..."
  sudo zypper refresh
  sudo zypper install -y zeal
}

case "$ID" in
ubuntu | debian | linuxmint)
  install_zeal_debian
  ;;
fedora | rhel | rocky | alma)
  install_zeal_rhel
  ;;
arch)
  install_zeal_arch
  ;;
opensuse* | suse)
  install_zeal_opensuse
  ;;
*)
  echo "Unsupported or unrecognized Linux distribution: $ID"
  exit 2
  ;;
esac

echo "Zeal installation completed."
