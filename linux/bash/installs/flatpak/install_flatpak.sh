#!/bin/bash

function check_flatpak_installed {
  if ! command -v flatpak > /dev/null 2>&1; then
    return 1
  else
    return 0
  fi
}

function add_flathub_repo {
  flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  return $?
}

function apt_install_flatpak {
  sudo apt install flatpak
  return $?
}

if [[ $BASH_SOURCE = "$0" ]]; then

  flatpak_installed=$(check_flatpak_installed)
  if [[ $flatpak_installed -eq 0 ]]; then
    echo "Flatpak is installed"
    add_flathub_repo
    if [[ $? -eq 0 ]]; then
      echo "Flathub repo added"
    else
      echo "Failed to add Flathub repo"
      exit 1
    fi
  else
    echo "[WARNING] Flatpak is not installed"
    apt_install_flatpak
    if [[ $? -eq 0 ]]; then
      echo "Flatpak installed successfully"
    else
      echo "Failed to install Flatpak"
      exit 1
    fi
  fi

  exit 0
fi
