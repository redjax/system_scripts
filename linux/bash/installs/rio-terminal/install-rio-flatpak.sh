#!/usr/bin/env bash

RIO_FLATPAK_CONF_DIR="$HOME/.var/app/com.rioterm.Rio/config/rio"
RIO_NATIVE_CONF_DIR="$HOME/.config/rio"

## Check if flatpak is installed
if ! command -v flatpak &> /dev/null; then
    echo "Error: Flatpak is not installed. Please install it first."
    exit 1
fi

## Check if Flathub remote is set up
if ! flatpak remotes --columns=name | grep -q '^flathub$'; then
    echo "Flathub remote not found. Adding Flathub..."
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    if [[ $? -ne 0 ]]; then
      echo "Added flathub remote to flatpak"
    fi
fi

## Check if Rio is already installed
if flatpak info com.rioterm.Rio &> /dev/null; then
    echo "Rio Flatpak is already installed."
else
    echo "Installing Rio terminal from Flathub"

    ## Install rio from flathub
    flatpak install -y flathub com.rioterm.Rio
    if [[ $? -ne 0 ]]; then
      echo "Failed to install Rio terminal flatpak"
      exit $?
    fi
fi

if [[ ! -d "$RIO_FLATPAK_CONF_DIR" ]]; then
    if [[ -d "$RIO_NATIVE_CONF_DIR" ]]; then
        echo "Copying Rio config files from '$RIO_NATIVE_CONF_DIR' to '$RIO_FLATPAK_CONF_DIR'"
        cp -R "$RIO_NATIVE_CONF_DIR" "$RIO_FLATPAK_CONF_DIR"
        if [[ $? -ne 0 ]]; then
            echo "[ERROR] Failed copying Rio config from '$RIO_NATIVE_CONF_DIR' to '$RIO_NATIVE_CONF_DIR'"
            exit $?
        fi
    else
        echo "[WARNING] No Rio configuration exists at '$RIO_NATIVE_CONF_DIR'. Skipping copy."
    fi
else
    echo "Rio flatpak config dir '$RIO_FLATPAK_CONF_DIR' already exists."
fi

echo "Rio terminal installed."
exit 0

