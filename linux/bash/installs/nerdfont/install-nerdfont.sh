#!/bin/bash

## Ripped off from https://github.com/ryanoasis/nerd-fonts?tab=readme-ov-file#option-7-install-script

##
# Instructions:
#   1. Find a nerd font from the URL above.
#   2. Navigate to a directory with a .ttf or .otf file in it and copy the URL to the .ttf/.otf file
#   3. Run this script, passing the URL(s) to it, i.e.:
#
#      ./install-nerdfont.sh \
#        "https://github.com/ryanoasis/nerd-fonts/blob/master/patched-fonts/Hack/Regular/HackNerdFont-Regular.ttf" \
#        "https://github.com/ryanoasis/nerd-fonts/blob/master/patched-fonts/FiraMono/Regular/FiraMonoNerdFont-Regular.otf"
##

function install_nerdfont_old {
    FONT_NAME=$1
    REPO_PATH=$2

    if ! command -v git --version > /dev/null 2>&1 ; then
        echo "[ERROR] git is not installed."
        return 1
    fi

    if [[ "${FONT_NAME}" == "" ]]; then
        FONT_NAME="Hack"
    fi

    if [[ "${REPO_PATH}" == "" ]]; then
        REPO_PATH="$HOME/.nerdfonts"
    fi

    if [[ ! -d "${REPO_PATH}" ]]; then
        echo "Cloning ryanoasis/nerd-fonts to ${REPO_PATH}"
        git clone --depth=1 https://github.com/ryanoasis/nerd-fonts.git "${REPO_PATH}"
        if [[ $? -ne 0 ]]; then
            echo "[ERROR] error while cloning ryanoasis/nerd-fonts to ${REPO_PATH}"
            return 1
        fi
    fi

    echo "Installing font ${FONT_NAME}"
    "${REPO_PATH}/install.sh" "${FONT_NAME}"
    if [[ $? -ne 0 ]]; then
        echo "[ERROR] error while installing font ${FONT_NAME}"
        return 1
    fi

    echo "Installed font ${FONT_NAME}"
    return 0
}

function install_nerdfont {
    ## See all fonts at:
    #  https://github.com/ryanoasis/nerd-fonts/tree/master/patched-fonts
    INSTALL_FONT_URLS=("$@")
    START_PATH=$(pwd)

    if ! command -v git --version > /dev/null 2>&1 ; then
        echo "[ERROR] git is not installed."
        return 1
    fi

    if ! command -v curl --version > /dev/null 2>&1 ; then
        echo "[ERROR] curl is not installed."
        return 1
    fi
    
    if [[ ${#INSTALL_FONT_URLS[@]} -eq 0 ]]; then
        INSTALL_FONT_URLS=(
            "https://github.com/ryanoasis/nerd-fonts/blob/master/patched-fonts/Hack/Regular/HackNerdFont-Regular.ttf"
            "https://github.com/ryanoasis/nerd-fonts/blob/master/patched-fonts/FiraMono/Regular/FiraMonoNerdFont-Regular.otf"
            "https://github.com/ryanoasis/nerd-fonts/tree/master/patched-fonts/FiraCode/Regular/FiraCodeNerdFontMono-Regular.ttf"
            "https://github.com/ryanoasis/nerd-fonts/tree/master/patched-fonts/FiraCode/Regular/FiraCodeNerdFont-Regular.ttf"
        )
    fi

    if [[ ! -d $HOME/.local/share/fonts ]]; then
        echo "Creating directory '$HOME/.local/share/fonts'"
        mkdir -p $HOME/.local/share/fonts
        if [[ $? -ne 0 ]]; then
            echo "[ERROR] error while creating directory '$HOME/.local/share/fonts'"
            return 1
        fi
    fi

    echo "Downloading [${#INSTALL_FONT_URLS[@]}] font(s)"
    cd $HOME/.local/share/fonts

    for FONT_URL in "${INSTALL_FONT_URLS[@]}"; do
        echo "Downloading font: ${FONT_URL}"

        curl -fLO "${FONT_URL}"
        if [[ $? -ne 0 ]]; then
            echo "[ERROR] error while downloading font(s)."
        fi
    done

    if [[ $? -ne 0 ]]; then
        echo "[ERROR] error while downloading font(s). Make sure the font is available here: https://github.com/ryanoasis/nerd-fonts/tree/master/patched-fonts"
        return 1
    fi

    echo "Finished installing font(s)"
    cd $START_PATH
    return 0

}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  install_nerdfont "$@"
  if [[ $? -ne 0 ]]; then
    echo "Failed to install nerdfont(s)"
    exit 1
  fi
fi
