#!/bin/bash

DEFAULT_FLATPAK_APPS=()

function install_flatpak_apps {
  FLATPAK_APPS=("$@")
  
  if ! command -v flatpak > /dev/null 2>&1; then
    echo "[ERROR] Flatpak is not installed."
    return 1
  fi

  if [[ ${#FLATPAK_APPS[@]} -eq 0 ]]; then
    echo "[ERROR] No Flatpak apps specified. Pass an array of flatpak names, for example:"
    echo "  install_flatpak_apps \"md.osbidian.Obsidian\" \"org.mozilla.firefox\""
    return 1
  fi

  echo "Installing [${#FLATPAK_APPS[@]}] Flatpak app(s)"
  for APP in "${FLATPAK_APPS[@]}"; do
    flatpak install --user flathub $APP
  done
}

if [[ "${BASH_SOURCE[0]}" ==  "${0}" ]]; then
  install_flatpak_apps
  if [[ $? -ne 0 ]]; then
    echo "[ERROR] Error installing Flatpak apps."
    exit 1
  else
    echo "Flatpak app(s) installed successfully"
    exit 0
  fi
fi
